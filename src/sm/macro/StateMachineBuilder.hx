package sm.macro;


#if macro
import haxe.macro.ComplexTypeTools;
import tink.macro.Ops.Binary;
import tink.macro.Exprs.VarDecl;
import haxe.macro.MacroStringTools;
import tink.macro.Ops.Unary;
import tink.macro.ConstParam;
import sm.tools.StateMachineModel;
import sm.tools.Visio;
import haxe.macro.Printer;
import haxe.macro.Context;
import haxe.macro.Expr;
import tink.macro.Member;
import sm.tools.StateXMLTools;
import sm.tools.MacroTools;

using tink.MacroApi;

class StateMachineBuilder {
	static function makeFinalInt(n:String, v:Int) {
		var newField = {
			name: n,
			doc: null,
			meta: [],
			access: [AStatic, APublic, AFinal],
			kind: FVar(macro:Int, v.toExpr()),
			pos: Context.currentPos()
		};

		return newField;
	}

	static function makeMemberFunction(n:String, f:Function):Field {
		var func = {
			name: n,
			doc: null,
			meta: [],
			access: [APublic],
			kind: FFun(f),
			pos: Context.currentPos()
		};
		return func;
	}

	static function buildConstants(cb:tink.macro.ClassBuilder, model:StateMachineModel) {
		for (ss in model.stateShapes) {
			//   trace("StateShape:" + ss.nodeName);
		}
		var count = 0;
		for (ss in model.stateNames) {
			cb.addMember(makeFinalInt("S_" + ss, count++));
			//            trace("State name:" + ss);
		}
		count = 0;
		for (ss in model.transitionNames) {
			cb.addMember(makeFinalInt("T_" + ss, count++));
			//            trace("State name:" + ss);
		}
	}

	static function buildVars(cb:tink.macro.ClassBuilder, model:StateMachineModel) {
		var count = 0;
		for (ds in model.defaultStates) {
			var stateField = {
				name: "_state" + count,
				doc: null,
				meta: [],
				access: [APrivate],
				kind: FVar(macro:Int, Exprs.at(EConst(CIdent("S_" + ds)))),
				pos: Context.currentPos()
			};

			cb.addMember(stateField);
		}


		cb.addMember(Member.prop( "state", macro:Int, Context.currentPos(), false, true));
		cb.addMember(Member.getter("state", null, macro return _state0, macro :Int));

		cb.addMember(Member.prop( "stateName", macro:String, Context.currentPos(), false, true));

		var cases = new Array<Case>();

		for (i in 0...model.stateNames.length) {
			var c:Case = {values: [exprConstInt(i)], expr: exprRet(exprConstString(model.stateNames[i]))};
			cases.push(c);
		}

		var sw = Exprs.at(ESwitch(Exprs.at(EConst(CIdent("_state0"))), cases, Exprs.at(EThrow(Exprs.at(EConst(CString("State not found")))))));
		cb.addMember(Member.getter("stateName", null, sw, macro :String));

		var ct = tink.macro.Types.asComplexType(getInterfaceName());
		var listeneners = {
			name: "_listeners",
			doc: null,
			meta: [],
			access: [APrivate],
			kind: FVar(Types.asComplexType("Array", [TPType(ct)]), Exprs.at(ENew(Types.asTypePath("Array", [TPType(ct)]), []))),
			pos: Context.currentPos()
		};

		cb.addMember(listeneners);

		cb.addMember(makeMemberFunction("addListener", Functions.func( macro _listeners.push(l), [Functions.toArg("l", ct)])));
	}

	static function buildFireFunction(cb:tink.macro.ClassBuilder, model:StateMachineModel) {
		var stateCases = new Array<Case>();

		for (s in model.stateShapes) {
			if (isGroupNode(s) || isGroupProxy(s))
				continue;
			var content = getStateShapeName(s);
			if (content == null)
				continue;

			var triggers = new Map<String, Bool>();
			var currentElement = s;

			var triggerCases = new Array<Case>();

			while (s != null && (isStateShape(s) || isGroupNode(s))) {
				var parent = s.parent.parent;
				if (isGroupProxy(s)) {
					s = parent;
					parent = getParentGroup(s);
				}
				model.graph.walkOutgoingConnections(s, x -> trace('Missing transition information on ${x}'), (trigger, targetState) -> {
					var sourceStateName = getStateShapeName(s);
					var targetStateName = getStateShapeName(targetState);
					if (triggers.exists(trigger)) {
						throw "Overlapping triggers " + trigger;
					}

					var blockArray = new Array<Expr>();

					var exited = new Array<String>();
					exited.push(sourceStateName);
					blockArray.push(exprCall("onExit" + sourceStateName, [exprID("trigger")]));

					var leafState = getInitialLeaf(targetState);
					var leafStateName = getStateShapeName(leafState);

					var commonRoot = firstCommonAncestor(s, leafState);
					var parent = getParentGroup(s);

					while (parent != commonRoot && parent != null) {
						var pName = getStateShapeName(parent);
						blockArray.push(exprCall("onExit" + pName, [exprID("trigger")]));
						exited.push(pName);
						parent = getParentGroup(parent);
					}

					var walkList = new Array<Xml>();

					parent = getParentGroup(leafState);
					while (parent != commonRoot && parent != null) {
						walkList.push(parent);
						parent = getParentGroup(parent);
					}

					walkList.reverse();

					for (targetAncestor in walkList) {
						for (exit in exited) {
							blockArray.push(exprCall("onEnterFrom" + getStateShapeName(targetAncestor), [exprID("S_" + exit)]));
						}
						blockArray.push(exprCall("onEnterBy" + getStateShapeName(targetAncestor), [exprID("T_" + trigger)]));
					}
					// TBD Support multiple machines
					blockArray.push(Exprs.assign(exprID("_state0"), exprID("S_" + leafStateName)));

					for (exit in exited) {
						blockArray.push(exprCall("onEnterFrom" + leafStateName, [exprID("S_" + exit)]));
					}

					blockArray.push(exprCall("onEnterBy" + leafStateName, [exprID("T_" + trigger)]));
					var tc:Case = {values: [Exprs.at(EConst(CIdent("T_" + trigger)))], expr: Exprs.toBlock(blockArray)};
					triggerCases.push(tc);
				});
				s = parent;
			}

			var triggerSwitch = Exprs.at(ESwitch(Exprs.at(EConst(CIdent("trigger"))), triggerCases, null));

			var stateCasec:Case = {values: [Exprs.at(EConst(CIdent("S_" + content)))], expr: triggerSwitch};
			stateCases.push(stateCasec);
		}

		var switches = new Array<Expr>();

		for (i in 0...model.defaultStates.length) {
			var sw = Exprs.at(ESwitch(Exprs.at(EConst(CIdent("_state" + i))), stateCases, Exprs.at(EThrow(Exprs.at(EConst(CString("State not found")))))));
			switches.push(sw);
		}

		var blk = Exprs.at(EBlock(switches));
		var arg:FunctionArg = {name: "trigger", type: macro:Int};
		var fun:Function = {args: [arg], expr: blk};

		var fireFunc = {
			name: "fire",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FFun(fun),
			pos: Context.currentPos()
		};

		cb.addMember(fireFunc);
	}

	static function buildIsInFunction(cb:tink.macro.ClassBuilder, model:StateMachineModel) {
		var blockArray = new Array<Expr>();

		blockArray.push(exprIf(exprEq(exprID("_state0"), exprID("state")), macro return true));

		var cases = new Array<Case>();

		for (s in model.stateShapes) {
			if (isGroupNode(s) || isGroupProxy(s))
				continue;
			var content = getStateShapeName(s);
			if (content == null)
				continue;

			var parent = getParentGroup(s);
			if (parent == null || isEmpty(getStateShapeName(parent)))
				continue;

			var subcases = new Array<Case>();

			while (parent != null && isGroupNode(parent)) {
				var c:Case = {values: [exprID("S_" + getStateShapeName(parent))], expr: macro return true};
				subcases.push(c);

				parent = getParentGroup(parent);
			}

			var theCase:Case = {values: [Exprs.at(EConst(CIdent("S_" + getStateShapeName(s))))], expr: Exprs.at(ESwitch(exprID("state"), subcases, null))};
			cases.push(theCase);
		}

		var sw = Exprs.at(ESwitch(Exprs.at(EConst(CIdent("_state0"))), cases, Exprs.at(EThrow(Exprs.at(EConst(CString("State not found")))))));

		blockArray.push(sw);
		blockArray.push(macro return false);

		cb.addMember({
			name: "isIn",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FFun({args: [{name: "state", type: macro:Int}], expr: Exprs.at(EBlock(blockArray))}),
			pos: Context.currentPos()
		});
	}

	static function buildFireStrFunction(cb:tink.macro.ClassBuilder, model:StateMachineModel) {
		var cases = new Array<Case>();

		for (t in model.transitionNames) {
			var c:Case = {values: [exprConstString(t)], expr: Exprs.at(ECall(Exprs.at(EConst(CIdent("fire"))), [Exprs.at(EConst(CIdent("T_" + t)))]))};
			cases.push(c);
		}

		var sw = Exprs.at(ESwitch(Exprs.at(EConst(CIdent("trigger"))), cases, Exprs.at(EThrow(Exprs.at(EConst(CString("Trigger not found")))))));

		var arg:FunctionArg = {name: "trigger", type: macro:String};
		var fun:Function = {args: [arg], expr: sw};

		var fireFunc = {
			name: "fireStr",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FFun(fun),
			pos: Context.currentPos()
		};

		cb.addMember(fireFunc);
	}



	static public function buildEventFunctions(cb:tink.macro.ClassBuilder, model:StateMachineModel) {
		for (s in model.stateNames) {
			var enterByName = exprID("onEnterBy" + s);
			var index = macro _listeners[i];

			var call = Exprs.at(EField(index, "onEnterBy" + s));
			var enterByExpr = exprFor(macro i, macro _listeners.length, macro $call(trigger));
			cb.addMember(makeMemberFunction("onEnterBy" + s, Functions.func(Exprs.toBlock([enterByExpr]), [Functions.toArg("trigger", macro:Int)])));

			call = Exprs.at(EField(index, "onExit" + s));
			enterByExpr = exprFor(macro i, macro _listeners.length, macro $call(trigger));
			cb.addMember(makeMemberFunction("onExit" + s, Functions.func(Exprs.toBlock([enterByExpr]), [Functions.toArg("trigger", macro:Int)])));

			call = Exprs.at(EField(index, "onEnterFrom" + s));
			enterByExpr = exprFor(macro i, macro _listeners.length, macro $call(state));
			cb.addMember(makeMemberFunction("onEnterFrom" + s, Functions.func(Exprs.toBlock([enterByExpr]), [Functions.toArg("state", macro:Int)])));
		}
	}

	static var _machines = new Map<String, StateMachineModel>();

	static function getMachine(path:String, machine:String):StateMachineModel {
		var key = path + "_" + machine;
		var m = _machines.get(key);

		if (m == null) {
			var smArray = Visio.read(path);
			for (sm in smArray) {
				var key = path + "_" + sm.name;
				_machines[key] = sm;
			}
		}
		m = _machines.get(key);
		if (m == null) {
			throw 'No machine ${machine} found in ${path}';
		}
		return m;
	}

	static var _printer = new Printer();

	static function getInterfaceName() {
		return "I" + Context.getLocalClass().get().name + "Listener";
	}

	static public function buildInterface(path:String, machine:String) {
		var model = getMachine(path, machine);

		var cb = new tink.macro.ClassBuilder();

		var moduleName = Context.getLocalModule();

		for (s in model.stateNames) {
			var x:Function = {args: [Functions.toArg("trigger", macro:Int)]};

			cb.addMember(makeMemberFunction("onEnterBy" + s, {ret: macro:Void, args: [Functions.toArg("trigger", macro:Int)]}));
			cb.addMember(makeMemberFunction("onExit" + s, {ret: macro:Void, args: [Functions.toArg("trigger", macro:Int)]}));
			cb.addMember(makeMemberFunction("onEnterFrom" + s, {ret: macro:Void, args: [Functions.toArg("state", macro:Int)]}));
		}

		var xx = cb.export(false);

		for (x in xx) {
			trace(_printer.printField(x));
		}

		Context.defineType({
			pack: Context.getLocalClass().get().pack,
			name: getInterfaceName(),
			pos: Context.currentPos(),
			kind: TDClass(null, null, true),
			fields: xx
		});

		return xx;
	}

	static function buildConstructor(cb:tink.macro.ClassBuilder, model:StateMachineModel) {

		var con = cb.getConstructor();
		
		con.init("_state0", Context.currentPos(),Value(exprID("S_" + model.defaultStates[0])) );
		con.publish();
	}

	macro static public function build(path:String, machine:String, makeInterface:Bool, constructor:Bool):Array<Field> {
		var model = getMachine(path, machine);

		var cb = new tink.macro.ClassBuilder();
		
		buildConstants(cb, model);
		buildVars(cb, model);
		if (constructor) {
			buildConstructor(cb,model);
		}
		
		buildEventFunctions(cb, model);
		buildFireFunction(cb, model);
		buildIsInFunction(cb, model);
		buildFireStrFunction(cb, model);

		if (makeInterface) {
			buildInterface(path, machine);
		}
		var xx = cb.export(false);

		for (x in xx) {
			trace(_printer.printField(x));
		}
		return xx;
	}
}
#end
