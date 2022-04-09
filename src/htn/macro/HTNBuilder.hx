package htn.macro;

#if macro
import haxe.macro.Expr;
import htn.Parser;
import haxe.macro.Context;

using tink.MacroApi;
using haxe.macro.MacroStringTools;
using StringTools;

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

	static function getNumericExpression(ne:NumericExpression) {
		trace('NE: ${ne}');
		switch (ne) {
			case NELiteral(value):
				return EConst(CFloat(value)).at();
			default:
		}
		return null;
	}

	static function generate(ast:Array<Declaration>):Array<Field> {
		var fields = Context.getBuildFields();

		var constants = ast.filter((x) -> switch (x) {
			case DVariable(kind, _, _, _):
				kind == VKConstant;
			default: false;
		});

		var abstractCount = 0;
		var operatorCount = 0;

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
					var c:Case = {
						values: [macro $i{"O_" + name.toUpperCase()}],
						expr: macro {}
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

             function makeSetter( name : String, type : ExpressionType ) {
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

		var mp = new haxe.macro.Printer();

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
