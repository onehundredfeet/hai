package htn.macro;

#if macro
import haxe.macro.Expr;
import htn.Parser;
import haxe.macro.Context;

using tink.MacroApi;
using haxe.macro.MacroStringTools;
using StringTools;
using Lambda;

class HTNBuilder {
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

	static function getBinOp(op:String) : Binop{
		return switch(op) {
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

	static function generate(ast:Array<Declaration>):Array<Field> {
		var fields = Context.getBuildFields();
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
			case DOperator(name, parameters, condition, effects): declarationTable.set(name, x);
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
			case DOperator(name, parameters, condition, effects):
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
				case DOperator(name, parameters, condition, effects):
					var fn = macro $i{"resolve_" + name};
					var unwinds = effects.map( (x) -> {
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
			/*
				inline function setEnemyRange( v : Float ) {
					_effectStackValue.push(enemyRange);
					enemyRange = v;
				}
			 */

			function makeSetter(name:String, type:ExpressionType) {
				var ident = macro $i{name};
				var body = macro {
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
						case VKParameter: makeSetter(name, type);
						case VKLocal: makeSetter(name, type);
						default: null;
					}
				default: null;
			}).filter((x) -> x != null));
		}

		// Resolve functions
		{
			function makeOperator(name:String, parameters:Array<Parameter>, condition:BooleanExpression, effects:Array<Effect>) {
				var ident = macro $i{name};

				trace ('Effects: ${effects}');
				var effectsExpr = effects.map((x) -> {
					trace('Effect: ${x}');
					//                        var targetIdent = macro $i{x.state};
					var expr = getNumericExpression(x.expression);
					var call_ident = macro $i{"set_" + x.state};
					return macro $call_ident($expr);
				});

				/*
							
							if (enemyVisible && enemyVisible) {
								setEnemyRange(enemyRange + val_f);
								myOperator2(val_f);
								return concreteSuccess(O_OPERATOR2);
							}

							return BranchState.Failed;
				 */

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
							case DOperator(name, parameters, condition, effects): (macro $i{'operator_${name}'}).call();
							default:
								Context.error('${decl} is not a subtask', Context.currentPos());
								macro "";
						}
						return macro $call == BranchState.Success;
					});

					var resolves = se.fold((x, y) -> macro $x && $y, macro true);

					var cond = getBooleanExpression(m.condition);
					var expr = macro if ($cond && $resolves)
						return BranchState.Success;
					trace(mp.printExpr(expr));
					methodBlocks.push(expr);
				}

				var body = macro {
					var next_depth = depth - 1;
					if (next_depth <= 0)
						return BranchState.Incomplete;

					var concrete_progress = _concretePlan.length;

					$b{methodBlocks};

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
				case DOperator(name, parameters, condition, effects): makeOperator(name, parameters, condition, effects);
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

		{
			var bodyBlock = macro {
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

		for (d in ast) {
			trace('${d}');
		}

		for (f in fields) {
			trace(mp.printField(f));
		}

		return fields;
	}

	public static function build(path:String):Array<Field> {
		var parse = new Parser();

		var content = try {
			sys.io.File.getBytes(path);
		} catch (e:Dynamic) {
			Context.error('Can\'t find HTN file ${path}', Context.currentPos());
			return null;
		}

		try {
			var ast = parse.parseFile(path, new haxe.io.BytesInput(content));
			return generate(ast);
		} catch (msg:String) {
			Context.error('Parse error ${msg}', Context.currentPos());
			return null;
		}

		return null;
	}
}
#end
