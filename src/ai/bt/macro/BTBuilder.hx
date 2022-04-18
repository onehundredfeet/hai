package ai.bt.macro;

#if macro
import haxe.macro.Expr;
import ai.bt.Parser;
import haxe.macro.Context;
import ai.tools.AST;

using tink.MacroApi;
using haxe.macro.MacroStringTools;
using StringTools;
using Lambda;

import ai.macro.MacroTools;

class BTBuilder {
	static function getExpressionType(et:ExpressionType) {
		switch (et) {
			case ETFloat:
				return Context.getType("Float").toComplex();
			case ETBool:
				return Context.getType("Bool").toComplex();
			case ETInt:
				return Context.getType("Int").toComplex();
			case ETUser(name):
				return Context.getType(name).toComplex();
		}
		return null;
	}

	static function getBinOp(op:String):Binop {
		return switch (op) {
			case "+": return Binop.OpAdd;
			case "-": return Binop.OpSub;
			case "*": return Binop.OpMult;
			case "/": return Binop.OpDiv;
			case "&": return Binop.OpBoolAnd;
			case "&&": return Binop.OpBoolAnd;
			case ">": return Binop.OpGt;
			case "<": return Binop.OpLt;
			case ">=": return Binop.OpGte;
			case "<=": return Binop.OpLte;
			case "=": return Binop.OpEq;
			case "==": return Binop.OpEq;
			default:
				Context.error('Unknown operator ${op}', Context.currentPos());
		}
	}

	static function getNumericExpression(ne:NumericExpression):haxe.macro.Expr {
		//		trace('NE: ${ne}');
		return switch (ne) {
			case NELiteral(value): EConst(CFloat(value)).at();
			case NEIdent(name): macro $i{name};
			case NEBinaryOp(op, left, right): EBinop(getBinOp(op), getNumericExpression(left), getNumericExpression(right)).at();
			default: Context.error('Unknown numeric expression ${ne}', Context.currentPos());
		}
	}

	static function getBooleanExpression(be:BooleanExpression) {
		//		trace('BE: ${be}');
		return switch (be) {
			case BELiteral(isTrue): isTrue ? macro true : macro false;
			case BEIdent(name): macro $i{name};
			case BEBinaryOp(op, left, right): EBinop(getBinOp(op), getBooleanExpression(left), getBooleanExpression(right)).at();
			default: Context.error('Unknown boolean expression ${be}', Context.currentPos());
		}
	}

	static function cleanIdentifier(s:String):String {
		if (s.startsWith("A_")) {
			return s.substr(2).toUpperCase();
		}
		if (s.startsWith("O_")) {
			return s.substr(2).toUpperCase();
		}
		return s.toUpperCase();
	}

	static function addActions(map:Map<String, Array<Field>>, meta:Array<Array<Expr>>, f:Field) {
		if (meta == null)
			return;
		for (se in meta) {
			for (p in se) {
				var state = Exprs.getIdent(p);

				if (state.isSuccess()) {
					var stateName = cleanIdentifier(state.sure());
					if (!map.exists(stateName))
						map[stateName] = new Array<Field>();
					map[stateName].push(f);
				}
			}
		}
	}

	static function generate(ast:Array<Declaration>, debug:Bool):Array<Field> {
		var fields = Context.getBuildFields();

		// Build meta data
		var operatorMap = new Map<String,Array<Field>>();
		var beginMap = new Map<String,Array<Field>>();

		fields.map((x) -> {
			if (x.kind.match(FFun(_))) {
				var y = x.meta.toMap();
				if (y.exists(":tick")) {
					var opNames = y.get(":tick");
					for (olist in opNames) {
						for (o in olist) {
							var oname = getStringValue(o);
							trace('Found operator ${oname}');

							var ofields = operatorMap.get(oname);
							if (ofields == null) {
								ofields = new Array<Field>();
								operatorMap.set(oname, ofields);
							}
							ofields.push(x);
						}
					}
				}
				if (y.exists(":begin")) {
					var opNames = y.get(":begin");
					for (olist in opNames) {
						for (o in olist) {
							var oname = getStringValue(o);
							trace('Found operator ${oname}');

							var ofields = beginMap.get(oname);
							if (ofields == null) {
								ofields = new Array<Field>();
								beginMap.set(oname, ofields);
							}
							ofields.push(x);
						}
					}
				}
			}
		});

		var mp = new haxe.macro.Printer();
		var constants = ast.filter((x) -> switch (x) {
			case DVariable(kind, _, _, _):
				kind == VKConstant;
			default: false;
		});

		var abstractCount = 0;
		var operatorCount = 0;

		var declarationTable = new Map<String, Declaration>();

		ast.map((x) -> switch (x) {
			case DVariable(kind, name, type, value): declarationTable.set(name, x);
			case DAbstract(name, methods): declarationTable.set(name, x);
			case DOperator(name,  _, _, _, _): declarationTable.set(name, x);
            case DSequence(name, _, _, _, _, _):declarationTable.set(name, x);
		});

		fields = fields.concat(ast.map((x) -> switch (x) {
			case DVariable(kind, name, type, value):
				switch (kind) {
					case VKConstant: {
							name: name,
							doc: null,
							meta: [],
							access: [AStatic, APublic, AFinal, AInline],
							kind: FVar(getExpressionType(type), getNumericExpression(value)),
							pos: Context.currentPos()
						};
					case VKParameter: {
							name: name,
							doc: null,
							meta: [],
							access: [APublic],
							kind: FVar(getExpressionType(type), value != null ? getNumericExpression(value) : null),
							pos: Context.currentPos()
						};
					case VKLocal: {
							name: name,
							doc: null,
							meta: [],
							access: [],
							kind: FVar(getExpressionType(type), value != null ? getNumericExpression(value) : null),
							pos: Context.currentPos()
						};
				}
			case DAbstract(name, methods):
				{
					name: "A_" + name.toUpperCase(),
					doc: null,
					meta: [],
					access: [AStatic, APublic, AFinal, AInline],
					kind: FVar(macro:Int, (abstractCount++).toExpr()),
					pos: Context.currentPos()
				};
			case DOperator(name, _, _,  _, _):
				{
					name: "O_" + name.toUpperCase(),
					doc: null,
					meta: [],
					access: [AStatic, APublic, AFinal, AInline],
					kind: FVar(macro:Int, (operatorCount++).toExpr()),
					pos: Context.currentPos()
				};
			default: null;
		}).filter((x) -> x != null));

        #if false
		fields.push({
			name: "_effectStackValue",
			doc: null,
			meta: [],
			access: [],
			kind: FVar(macro:Array<Dynamic>, macro new Array<Dynamic>()),
			pos: Context.currentPos()
		});

		fields.push({
			name: "_concretePlan",
			doc: null,
			meta: [],
			access: [],
			kind: FVar(macro:Array<Int>, macro new Array<Int>()),
			pos: Context.currentPos()
		});

		// unwind
		{
			var switch_block = ast.map((x) -> switch (x) {
				case DOperator(name,  condition, effects, _, _):
					var fn = macro $i{"resolve_" + name};
					var unwinds = effects.map((x) -> {
						var varIdent = macro $i{x.state};
						return macro $varIdent = _effectStackValue.pop();
					});
					unwinds.reverse();
					var c:Case = {
						values: [macro $i{"O_" + name.toUpperCase()}],
						expr: macro $b{unwinds}
					};
					c;

				default: null;
			}).filter((x) -> x != null);

			var switchExpr = ESwitch(macro x, switch_block, null).at();
			var unwind_block = macro {
				if (concreteLength < _concretePlan.length) {
					var x = _concretePlan.pop();
					$switchExpr;
				}
			};

			fields.push({
				name: "unwind",
				doc: null,
				meta: [],
				access: [],
				kind: FFun(unwind_block.func(["concreteLength".toArg(macro:Int)], macro:Void, null, false)),
				pos: Context.currentPos()
			});
		}

		// accessors
		{
			function makeSetter(name:String, type:ExpressionType, debug:Bool) {
				var ident = macro $i{name};

				var debugTrace = debug ? macro trace("Setting " + $e{name.toExpr()} + " to " + v) : macro {};
				var body = macro {
					$debugTrace;
					_effectStackValue.push($ident);
					$ident = v;
				};
				return {
					name: "set_" + name,
					doc: null,
					meta: [],
					access: [AInline],
					kind: FFun(body.func(["v".toArg(getExpressionType(type))])),
					pos: Context.currentPos()
				};
			}
			fields = fields.concat(ast.map((x) -> switch (x) {
				case DVariable(kind, name, type, value):
					switch (kind) {
						case VKParameter: makeSetter(name, type, debug);
						case VKLocal: makeSetter(name, type, debug);
						default: null;
					}
				default: null;
			}).filter((x) -> x != null));
		}

		// Resolve functions
		{
			function makeOperatorSim(name:String,  condition:BooleanExpression, effects:Array<Effect>) {
				var ident = macro $i{name};

				trace('Effects: ${effects}');
				var effectsExpr = effects.map((x) -> {
					trace('Effect: ${x}');
					//                        var targetIdent = macro $i{x.state};
					var expr = getNumericExpression(x.expression);
					var call_ident = macro $i{"set_" + x.state};
					return macro $call_ident($expr);
				});

				var cond = condition != null ? getBooleanExpression(condition) : macro true;
				var enumIdent = macro $i{"O_" + name.toUpperCase()};
				var body = macro {
					if ($cond) {
						$b{effectsExpr};
						return concreteSuccess($enumIdent);
					}
					return BranchState.Failed;
				};
				return {
					name: "operator_" + name,
					doc: null,
					meta: [],
					access: [],
					kind: FFun(body.func([])),
					pos: Context.currentPos()
				};
			}

			function makeResolve(name:String, methods:Array<Method>) {
				var ident = macro $i{name};
				var methodBlocks = new Array<Expr>();

				for (m in methods) {
					// {name : String, condition : BooleanExpression, subtasks : Array<SubTask>}
					var se = m.subtasks.map((x) -> {
						var decl = declarationTable.get(x.name);
						if (decl == null)
							Context.error('Could not find declaration ${x.name}', Context.currentPos());
						var call = switch (decl) {
							case DAbstract(name, methods):
								(macro $i{'resolve_${name}'}).call([macro $i{"next_depth"}]);
							case DOperator(name, _, _, _): (macro $i{'operator_${name}'}).call();
							default:
								Context.error('${decl} is not a subtask', Context.currentPos());
								macro "";
						}
						return macro $call == BranchState.Success;
					});

					//Folding and && nesting need to work oppositely
					se.reverse();
					var resolves = se.fold((x, y) -> macro $x && $y, macro true);

					var cond = getBooleanExpression(m.condition);
					var expr = macro if ($cond && $resolves)
						return BranchState.Success;
					trace(mp.printExpr(expr));
					methodBlocks.push(expr);
				}

				var resolveMessage = ("Resolving " + name).toExpr();
				var resolveTrace  = debug ? macro trace($resolveMessage + " : d " + depth): macro {};

				var body = macro {
					$resolveTrace;
					var next_depth = depth - 1;
					if (next_depth <= 0)
						return BranchState.Incomplete;

					var concrete_progress = _concretePlan.length;

					$b{methodBlocks};

					$e{ (debug ? macro trace ("Unwinding...") : macro {} )};
					unwind(concrete_progress);
					return BranchState.Failed;
				};
				return {
					name: "resolve_" + name,
					doc: null,
					meta: [],
					access: [],
					kind: FFun(body.func(["depth".toArg(macro:Int)])),
					pos: Context.currentPos()
				};
			}

			fields = fields.concat(ast.map((x) -> switch (x) {
				case DAbstract(name, methods): makeResolve(name, methods);
				case DOperator(name, condition, effects, _, _): makeOperatorSim(name, condition, effects);
				default: null;
			}).filter((x) -> x != null));
		}
		// Plan function
		{
			var switch_block = ast.map((x) -> switch (x) {
				case DAbstract(name, methods):
					var fn = macro $i{"resolve_" + name};
					var c:Case = {
						values: [macro $i{"A_" + name.toUpperCase()}],
						expr: macro return $fn(maxDepth)
					};
					c;

				default: null;
			}).filter((x) -> x != null);

			var plan_block = [];
			plan_block.push(macro _concretePlan.resize(0));
			plan_block.push(macro _effectStackValue.resize(0));
			plan_block.push(ESwitch(macro task, switch_block, null).at());
			plan_block.push(macro return BranchState.Failed);
			fields.push({
				name: "plan",
				doc: null,
				meta: [],
				access: [APublic],
				kind: FFun(EBlock(plan_block).at()
					.func(["task".toArg(macro:Int), "maxDepth".toArg(macro:Int, false, 99999.toExpr())], macro:BranchState, null, false)),
				pos: Context.currentPos()
			});
		}

		// Begin
		{
			var switchBlock = ast.map((x) -> switch (x) {
				case DOperator(name, condition, effects,  _, _): beginMap.exists(name) ? {
					var c : Case = {
						values: [macro $i{"O_" + name.toUpperCase()}],
						expr: EBlock(beginMap.get(name).map( 
							(x) -> {
								(macro $i{x.name}).call();
							}
						 )).at()
					};
					c;
				}: null;
				default: null;
			}).filter((x) -> x != null);
			var switchExpr = ESwitch(macro op, switchBlock, null).at();

			// beginOperator
			fields.push({
				name: "beginOperator",
				doc: null,
				meta: [],
				access: [AInline],
				kind: FFun(switchExpr.func(["op".toArg(macro:Int)], null, null, false)),
				pos: Context.currentPos()
			});
		}
		{
			var debugTrace = debug ?macro 
			{
				trace("Executing plan:");
//				_concretePlan.reverse();
				for( o in _concretePlan ) trace('\tOperator ${getOperatorName(o)}');
//				_concretePlan.reverse();
			}
			 : macro {};
			// Execute
			fields.push(makeField("execute", [APublic], (macro {
				$debugTrace;

				_concretePlan.reverse();
				var last = _concretePlan.length - 1;
				if (last < 0)
					return;
				beginOperator(_concretePlan[last]);
			}).func([], null, null, false)));
		}
		{
			var nameCases = ast.map((x) -> switch (x) {
				case DOperator(name,  condition, effects, parameters, calls):  {
					var c : Case = {
						values: [macro $i{"O_" + name.toUpperCase()}],
						expr: macro $e{name.toExpr()}
					};
					c;
				};
				default: null;
			}).filter((x) -> x != null);
			var nameSwitch = ESwitch( macro op, nameCases, "".toExpr()).at();
			// Operator name
			fields.push(makeField("getOperatorName", [APublic], (macro return $nameSwitch).func(["op".toArg(macro:Int)], macro :String, null, false)));
		}


		// Tick
		{
			function makeTickCallArguments(params : Array<Parameter>, f : Field) : Array<Expr>{

				switch(f.kind) {
					case FFun(func):
						return func.args.map( (x) -> 
						{
							var p = params.find( (y) -> y.name == x.name);
							if (p == null) Context.error('Required operator parameter ${x.name} not found', Context.currentPos());
							return getNumericExpression( p.expression );
						}
						);
					default:
				}
				return [];
			}
			var switchBlock = ast.map((x) -> switch (x) {
				case DOperator(name,  condition, effects, parameters, calls): operatorMap.exists(name) ? {
					var c : Case = {
						values: [macro $i{"O_" + name.toUpperCase()}],
						expr: EBlock(operatorMap.get(name).map( 
							(x) -> {
								var call = (macro $i{x.name}).call(makeTickCallArguments(parameters, x));
								// TODO [RC] - Make multi-call 
								macro status = $call;
							}
						 ).concat(calls.map((x) -> 
							(macro $i{x.name}).call(x.arguments.map( (arg) -> getNumericExpression(arg) ))
						 ))
						 
						 ).at()
					};
					c;
				}: null;
				default: null;
			}).filter((x) -> x != null);

			var switchExpr = ESwitch(macro _concretePlan[last], switchBlock, null).at();

			var tickDebugBlock = [];

			if (debug) {
				tickDebugBlock = ast.map((x) -> switch (x) {
					case DVariable(kind, name, type, value):
						switch (kind) {
							case VKConstant: macro trace("Constant " + $e{name.toExpr()} + " " + $i{name});
							case VKParameter: macro trace("Parameter " + $e{name.toExpr()} + " " + $i{name});
							case VKLocal: macro trace("Local " + $e{name.toExpr()} + " " + $i{name});
						}
					default: null;
				}).filter((x) -> x != null);
			}
			var tickDebug = debug ?  macro $b{tickDebugBlock}: macro {};
			fields.push(makeField("tick", [APublic], (macro {
				var last = _concretePlan.length - 1;
				if (last < 0)
					return ai.common.TaskResult.Completed;
				var status = ai.common.TaskResult.Completed;
				while (last >= 0 && status == ai.common.TaskResult.Completed) {
					// switch goes here
					$switchExpr;
					if (status == ai.common.TaskResult.Completed) {
						_concretePlan.pop();
						last--;

						if (last >= 0) {
							beginOperator(_concretePlan[last]);
						}
					}
				}
				$tickDebug;
				return status;
			}).func([], macro:ai.common.TaskResult, null, false)));
		}



		{
			var debugBlock = debug ? macro trace('Adding operator ${getOperatorName(task)}') : macro {};

			var bodyBlock = macro {
				$debugBlock;
				_concretePlan.push(task);
				return BranchState.Success;
			};

			fields.push({
				name: "concreteSuccess",
				doc: null,
				meta: [],
				access: [],
				kind: FFun(bodyBlock.func(["task".toArg(macro:Int)], macro:BranchState, null, false)),
				pos: Context.currentPos()
			});
		}
#end
		for (d in ast) {
			trace('${d}');
		}

		for (f in fields) {
			trace(mp.printField(f));
		}

		return fields;
	}

	public static function build(path:String, debug = false):Array<Field> {
		var parse = new Parser();

		var content = try {
			sys.io.File.getBytes(path);
		} catch (e:Dynamic) {
			Context.error('Can\'t find HTN file ${path}', Context.currentPos());
			return null;
		}

		try {
			var ast = parse.parseFile(path, new haxe.io.BytesInput(content));
			return generate(ast, debug);
		} catch (msg:String) {
			Context.error('Parse error ${msg}', Context.currentPos());
			return null;
		}

		return null;
	}
}
#end
