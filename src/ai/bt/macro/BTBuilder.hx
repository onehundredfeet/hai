package ai.bt.macro;

#if macro
import haxe.macro.Expr;
import ai.bt.Parser;
import haxe.macro.Context;
import ai.tools.AST;
import ai.macro.MacroTools;

using tink.MacroApi;
using haxe.macro.MacroStringTools;
using StringTools;
using Lambda;

import ai.macro.MacroTools;

class BTBuilder {
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

	static function getDeclarationTable(ast:Array<Declaration>) {
		var declarationTable = new Map<String, Declaration>();

		ast.map((x) -> switch (x) {
			case DVariable(kind, name, type, value): declarationTable.set(name, x);
			case DAbstract(name, methods): declarationTable.set(name, x);
			case DOperator(name, _, _, _, _): declarationTable.set(name, x);
			case DSequence(name, _, _, _, _, _): declarationTable.set(name, x);
			case DAction(name, _, _, _, _, _): declarationTable.set(name, x);
		});

		return declarationTable;
	}

	static function generateVariableFields(ast:Array<Declaration>):Array<Field> {
		return ast.flatMap((x) -> switch (x) {
			case DVariable(kind, name, type, value):
				var f : Field = switch (kind) {
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
                [f];
            case DSequence(name, parallel, all, restart, continued, looped, children):
                generateSequenceState( name, parallel, all, restart, continued, looped, children );
			default: [];
		}).filter((x) -> x != null);
	}

	static function generateVarField(name:String, ct:ComplexType, e:Expr):Field {
		return {
			name: name,
			doc: null,
			meta: [],
			access: [],
			kind: FVar(ct, e),
			pos: Context.currentPos()
		};
	}

	static function generateFuncField(name:String, f:Function):Field {
		return {
			name: name,
			doc: null,
			meta: [],
			access: [],
			kind: FFun(f),
			pos: Context.currentPos()
		};
	}

	static function generateSequenceChild(x:BehaviourChild) {
		return switch (x) {
			case BConditional(expr):
				var ne = getNumericExpression(expr);
				macro($ne ? TaskResult.Completed : TaskResult.Failed);
			case BChild(name, expr, decorators):
				var tname = "__tick_" + name;
				macro $i{tname}();
			default:
				throw('Unexpected child ${x}');
				null;
		}
	}

	static function generateSequenceState(name :String, parallel : Bool, all : Bool, restart : Bool, continued : Bool, looped : Bool, children : Array<BehaviourChild>):Array<Field> {
        var state = [];
        if (parallel) {
            for (i in 0...children.length) {
                state.push( generateVarField('__tick_${name}_res_${i}', macro :TaskResult, macro TaskResult.Running));
            }
        } else if (!restart) {
            state.push( generateVarField('__tick_${name}_head', macro :Int, macro 0));
        } 
		return state;
	}

	static function generateSequence(name:String, children:Array<BehaviourChild>,  bContinue : Bool):Function {
        var headName = '__tick_${name}_head';
        var headExpr = macro $i{headName};

        var statements = [];
        var childIdx = 0;

		var cases :Array<Case> = children.map((x) -> {
            var cid = childIdx++;
            {
                values : [cid.toExpr()],
                guard : null,
                expr : generateSequenceChild(x)
            }

		}).filter((x) -> x != null);

        
        var switchExpr = ESwitch(headExpr, cases, macro TaskResult.Failed ).at();
        var endExpr = childIdx.toExpr();

        var resetExpr = bContinue ? macro {} : macro $headExpr = 0;

        statements.push( macro for (i in $headExpr...$endExpr) { var res = $switchExpr; 
            switch(res) {
                case TaskResult.Completed:$headExpr++;
                case TaskResult.Failed: $resetExpr; return TaskResult.Failed;
                case TaskResult.Running: return TaskResult.Running;
            }
        });
        
        statements.push(macro $headExpr = 0);
		statements.push(macro return TaskResult.Completed);
		var body = macro $b{statements};

		return body.func([], macro:TaskResult, null, false);
	}

	static function generateRestartSequence(name:String, children:Array<BehaviourChild>):Function {
		var statements = [];
        
        statements.push(macro var res : TaskResult);

        statements = statements.concat(children.map((x) -> {
			var c = generateSequenceChild(x);
			macro if ((res = $c) != TaskResult.Completed)
				return res;
		}).filter((x) -> x != null));

		statements.push(macro return TaskResult.Completed);
		var body = macro $b{statements};

		return body.func([], macro:TaskResult, null, false);
	}

	static function generateFirst(name:String, children:Array<BehaviourChild>, restart: Bool):Function {
		var headName = '__tick_${name}_head';
        var headExpr = restart ? 0.toExpr() : macro $i{headName};

        var statements = [];
        var childIdx = 0;

		var cases :Array<Case> = children.map((x) -> {
            var cid = childIdx++;
            {
                values : [cid.toExpr()],
                guard : null,
                expr : generateSequenceChild(x)
            }

		}).filter((x) -> x != null);

        
        var switchExpr = ESwitch(headExpr, cases, macro TaskResult.Failed ).at();
        var endExpr = childIdx.toExpr();

        var resetExpr = restart ? macro {} : macro $headExpr = 0;
        var headIncExpr = restart ? macro {} : macro $headExpr++;
        statements.push( macro for (i in $headExpr...$endExpr) { 
			var res = $switchExpr; 
            switch(res) {
                case TaskResult.Completed:$resetExpr; return TaskResult.Completed;
                case TaskResult.Failed: $headIncExpr;
                case TaskResult.Running: return TaskResult.Running;
            }
        });
        
        statements.push(resetExpr);
		statements.push(macro return TaskResult.Failed);
		var body = macro $b{statements};

		return body.func([], macro:TaskResult, null, false);
	}

	static function generateParallelAll(name:String, children:Array<BehaviourChild>):Function {
        var statements = [];
        var childIdx = 0;

		statements.push( macro var result = TaskResult.Completed );
		var cases :Array<Case> = children.map((x) -> {
			var vn = '__tick_${name}_res_${childIdx}';
            var cid = childIdx++;
			var e = generateSequenceChild(x);
            {
                values : [cid.toExpr()],
                guard : null,
                expr : macro (($i{vn} == TaskResult.Running) ? $e : $i{vn})
            }

		}).filter((x) -> x != null);

        
        var switchExpr = ESwitch(macro i, cases, macro TaskResult.Failed ).at();
        var endExpr = childIdx.toExpr();

		childIdx = 0;
		var resetChildren = children.map( (x) -> 
			{
				var vn = '__tick_${name}_res_${childIdx}';
				childIdx++;
				macro $i{vn} = TaskResult.Running;
			}
		);
		
        var resetExpr = EBlock( resetChildren ).at();

        statements.push( macro for (i in 0...$endExpr) { 
			var res = $switchExpr; 
            switch(res) {
                case TaskResult.Completed:
                case TaskResult.Failed: $resetExpr; return TaskResult.Failed;
                case TaskResult.Running: result = TaskResult.Running;
            }
        });
        
        statements.push(macro if (result == TaskResult.Completed) $resetExpr);
		statements.push(macro return result);
		var body = macro $b{statements};
		
		return body.func([], macro:TaskResult, null, false);
	}

	static function generateParallelOne(name:String, children:Array<BehaviourChild>):Function {
		var statements = [];
        var childIdx = 0;

		statements.push( macro var result = TaskResult.Failed );
		var cases :Array<Case> = children.map((x) -> {
			var vn = '__tick_${name}_res_${childIdx}';
            var cid = childIdx++;
			var e = generateSequenceChild(x);
            {
                values : [cid.toExpr()],
                guard : null,
                expr : macro (($i{vn} == TaskResult.Running) ? $e : $i{vn})
            }

		}).filter((x) -> x != null);

        
        var switchExpr = ESwitch(macro i, cases, macro TaskResult.Failed ).at();
        var endExpr = childIdx.toExpr();

		childIdx = 0;
		var resetChildren = children.map( (x) -> 
			{
				var vn = '__tick_${name}_res_${childIdx}';
				childIdx++;
				macro $i{vn} = TaskResult.Running;
			}
		);
		
        var resetExpr = EBlock( resetChildren ).at();

        statements.push( macro for (i in 0...$endExpr) { 
			var res = $switchExpr; 
            switch(res) {
                case TaskResult.Completed: $resetExpr; return TaskResult.Completed;
                case TaskResult.Failed: 
                case TaskResult.Running: result = TaskResult.Running;
            }
        });
        
        statements.push(macro if (result == TaskResult.Failed) $resetExpr);
		statements.push(macro return result);
		var body = macro $b{statements};
		
		return body.func([], macro:TaskResult, null, false);
	}

	static function generateAction(name:String, async:Bool, condition:BooleanExpression, effects:Array<Effect>, parameters:Array<Parameter>,
			calls:Array<Call>):Function {
		var statements = [];
		statements.push(macro return TaskResult.Completed);
		var body = macro $b{statements};

		return body.func([], macro:TaskResult, null, false);
	}

	static function generateBTTicks(ast:Array<Declaration>) {
		return ast.map((x) -> switch (x) {
			case DSequence(name, parallel, all, restart, continued, looped, children):
				var f = if (all) {
					parallel ? generateParallelAll(name, children) : restart ? generateRestartSequence(name, children) : generateSequence(name, children, continued);
				} else {
					parallel ? generateParallelOne(name, children) : generateFirst(name, children, restart);
				}

				generateFuncField("__tick_" + name, f);
			case DAction(name, async, condition, effects, parameters, calls):
				var f = generateAction(name, async, condition, effects, parameters, calls);
				generateFuncField("__tick_" + name, f);
			default: null;
		}).filter((x) -> x != null);
	}

	static function generate(ast:Array<Declaration>, debug:Bool):Array<Field> {
		var fields = Context.getBuildFields();
		var mp = new haxe.macro.Printer();

		var tagToFuncMap = getTagFunctions(fields, [":tick", ":begin"]);
		var tickMap = tagToFuncMap.get(":tick");
		var beginMap = tagToFuncMap.get(":begin");

		var declarationTable = getDeclarationTable(ast);

		fields = fields.concat(generateVariableFields(ast));
		fields = fields.concat(generateBTTicks(ast));

		#if false
		var abstractCount = 0;
		var operatorCount = 0;

		#if false
		fields.push(generateVarField("_effectStackValue", macro:Array<Dynamic>, macro new Array<Dynamic>()));

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
				case DOperator(name, condition, effects, _, _):
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
			function makeOperatorSim(name:String, condition:BooleanExpression, effects:Array<Effect>) {
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

					// Folding and && nesting need to work oppositely
					se.reverse();
					var resolves = se.fold((x, y) -> macro $x && $y, macro true);

					var cond = getBooleanExpression(m.condition);
					var expr = macro if ($cond && $resolves)
						return BranchState.Success;
					trace(mp.printExpr(expr));
					methodBlocks.push(expr);
				}

				var resolveMessage = ("Resolving " + name).toExpr();
				var resolveTrace = debug ? macro trace($resolveMessage + " : d " + depth) : macro {};

				var body = macro {
					$resolveTrace;
					var next_depth = depth - 1;
					if (next_depth <= 0)
						return BranchState.Incomplete;

					var concrete_progress = _concretePlan.length;

					$b{methodBlocks};

					$e{(debug ? macro trace("Unwinding...") : macro {})};
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
				case DOperator(name, condition, effects, _, _): beginMap.exists(name) ? {
						var c:Case = {
							values: [macro $i{"O_" + name.toUpperCase()}],
							expr: EBlock(beginMap.get(name).map((x) -> {
								(macro $i{x.name}).call();
							})).at()
						};
						c;
					} : null;
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
		} {
			var debugTrace = debug ? macro {
				trace("Executing plan:");
				//				_concretePlan.reverse();
				for (o in _concretePlan)
					trace('\tOperator ${getOperatorName(o)}');
				//				_concretePlan.reverse();
			} : macro {};
			// Execute
			fields.push(makeField("execute", [APublic], (macro {
				$debugTrace;

				_concretePlan.reverse();
				var last = _concretePlan.length - 1;
				if (last < 0)
					return;
				beginOperator(_concretePlan[last]);
			}).func([], null, null, false)));
		} {
			var nameCases = ast.map((x) -> switch (x) {
				case DOperator(name, condition, effects, parameters, calls): {
						var c:Case = {
							values: [macro $i{"O_" + name.toUpperCase()}],
							expr: macro $e{name.toExpr()}
						};
						c;
					};
				default: null;
			}).filter((x) -> x != null);
			var nameSwitch = ESwitch(macro op, nameCases, "".toExpr()).at();
			// Operator name
			fields.push(makeField("getOperatorName", [APublic], (macro return $nameSwitch).func(["op".toArg(macro:Int)], macro:String, null, false)));
		}

		// Tick
		{
			function makeTickCallArguments(params:Array<Parameter>, f:Field):Array<Expr> {
				switch (f.kind) {
					case FFun(func):
						return func.args.map((x) -> {
							var p = params.find((y) -> y.name == x.name);
							if (p == null)
								Context.error('Required operator parameter ${x.name} not found', Context.currentPos());
							return getNumericExpression(p.expression);
						});
					default:
				}
				return [];
			}
			var switchBlock = ast.map((x) -> switch (x) {
				case DOperator(name, condition, effects, parameters, calls): operatorMap.exists(name) ? {
						var c:Case = {
							values: [macro $i{"O_" + name.toUpperCase()}],
							expr: EBlock(operatorMap.get(name).map((x) -> {
								var call = (macro $i{x.name}).call(makeTickCallArguments(parameters, x));
								// TODO [RC] - Make multi-call
								macro status = $call;
							}).concat(calls.map((x) -> (macro $i{x.name}).call(x.arguments.map((arg) -> getNumericExpression(arg)))))).at()
						};
						c;
					} : null;
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
			var tickDebug = debug ? macro $b{tickDebugBlock} : macro {};
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
		} {
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
