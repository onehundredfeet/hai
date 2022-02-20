package sm.macro;

import tink.core.Pair;
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
using StringTools;

typedef StateAction = {
	entries:Array<String>,
	exits:Array<String>,
	entrybys:Array<String>,
	entryfroms:Array<String>
}


typedef ActionMaps = {
	entry : Map<String, Array<Field>>,
	traverse: Map<String, Array<Field>>,
    entryBy : Map<String, Array<Pair<Field, String>>>,
    entryFrom : Map<String, Array<Pair<Field, String>>>,
    exit :  Map<String, Array<Field>>
}


class StateMachineBuilder {
	static function makeFinalInt(n:String, v:Int, ?t: ComplexType ) {
		var newField = {
			name: n,
			doc: null,
			meta: [],
			access: [AStatic, APublic, AFinal],
			kind: FVar((t == null) ? (macro:Int) : t, v.toExpr()),
			pos: Context.currentPos()
		};

		return newField;
	}
	

	static function makeMemberFunction(n:String, f:Function, isInline = false):Field {
		var func = {
			name: n,
			doc: null,
			meta: [],
			access: (isInline ? [APublic, AInline]: [APublic]),
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
			cb.addMember(makeFinalInt("S_" + ss, count++, macro : sm.State ));
			//            trace("State name:" + ss);
		}
		count = 0;
		for (ss in model.transitionNames) {
			cb.addMember(makeFinalInt("T_" + ss, count++, macro : sm.Transition ));
			//            trace("State name:" + ss);
		}
	}

	static function buildVars(cb:tink.macro.ClassBuilder, model:StateMachineModel, allowListeners: Bool) {

		cb.addMember( {
			name: "_inTransition",
			doc: null,
			meta: [],
			access: [APrivate],
			kind: FVar(macro:Bool, macro false ),
			pos: Context.currentPos()
		});

		cb.addMember( {
			name: "_triggerQueue",
			doc: null,
			meta: [],
			access: [APrivate],
			kind: FVar(macro:List<Int>, null ),
			pos: Context.currentPos()
		});

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

		cb.addMember(Member.prop("state", macro:Int, Context.currentPos(), false, true));
		cb.addMember(Member.getter("state", null, macro  _state0, macro:Int));

		cb.addMember(Member.prop("stateName", macro:String, Context.currentPos(), false, true));

		var cases = new Array<Case>();

		for (i in 0...model.stateNames.length) {
			var c:Case = {values: [exprConstInt(i)], expr: exprRet(exprConstString(model.stateNames[i]))};
			cases.push(c);
		}

		var sw = Exprs.at(ESwitch(Exprs.at(EConst(CIdent("_state0"))), cases, Exprs.at(EThrow(Exprs.at(EConst(CString("State not found")))))));
		cb.addMember(Member.getter("stateName", null, sw, macro:String));

		if (allowListeners) {
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

			cb.addMember(makeMemberFunction("addListener", Functions.func(macro _listeners.push(l), [Functions.toArg("l", ct)])));
		}
	}

	static function cleanState( s: String ) : String {
		if (s.startsWith("S_")) {
			return s.substr(2).toUpperCase();
		}
		return s.toUpperCase();
	}

	static function cleanIdentifier( s: String ) : String {
		if (s.startsWith("S_")) {
			return s.substr(2).toUpperCase();
		}
		if (s.startsWith("T_")) {
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
					var stateName =  cleanIdentifier(state.sure());
					if (!map.exists(stateName))
						map[stateName] = new Array<Field>();
					map[stateName].push(f);
				}
			}
		}
	}

	static function addConditionalActions(map:Map<String, Array<Pair<Field, String>>>, meta:Array<Array<Expr>>, f:Field) {
		if (meta == null)
			return;
		for (se in meta) {
			if (se.length >= 1) {
				var state = Exprs.getIdent(se[0]);
				if (state.isSuccess()) {
					var stateName =  cleanState(state.sure());

					if (!map.exists(stateName))
						map[stateName] = new Array<Pair<Field, String>>();

					if (se.length >= 2 && Exprs.getIdent(se[1]).isSuccess()) {
						map[stateName].push(new Pair(f, Exprs.getIdent(se[1]).sure()));
					} else {
						map[stateName].push(new Pair(f, null));
					}
				}
			}
			
		}
	}

	static function getActions() : ActionMaps {
		var entryMap = new Map<String, Array<Field>>();
		var traverseMap = new Map<String, Array<Field>>();
		var entryByMap = new Map<String, Array<Pair<Field, String>>>();
		var entryFromMap = new Map<String, Array<Pair<Field, String>>>();
		var exitMap = new Map<String, Array<Field>>();

		//		trace('Examining: ${Context.getLocalClass().get().name}');
		//		trace('Num Fields: ${Context.getLocalClass().get().fields.get().length}');
		//		trace('Build Fields: ${Context.getBuildFields().length}');
		for (field in Context.getBuildFields()) {
			switch (field.kind) {
				case FFun(fun):
					var mmap = field.meta.toMap();
					var enter = mmap.get(":enter");

					addActions(traverseMap, mmap.get(":traverse"), field);
					addActions(entryMap, mmap.get(":enter"), field);
					addActions(exitMap, mmap.get(":exit"), field);
					addConditionalActions(entryByMap, mmap.get(":enterby"), field);
					addConditionalActions(entryFromMap, mmap.get(":enterfrom"), field);

					/*
					var exit = mmap.get(":exit");
					var by = mmap.get(":enterby");
					var from = mmap.get(":enterfrom");
					var traverse = mmap.get(":traverse");

					if (enter != null || exit != null || by != null || from != null || traverse != null) {
						var x = {
							entries: enter,
							exits: exit,
							bys: by,
							froms: from
						}
					}
					if (enter != null) {
						for (se in enter) {
							for (p in se) {
								//trace('s:${Exprs.getIdent(p).orNull()}');
							}
						}
					}
					*/
				default:
					continue;
			}
		}

		return {
			entry: entryMap,
			traverse: traverseMap,
			entryBy: entryByMap,
			entryFrom: entryFromMap,
			exit: exitMap
		};
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


					// Does the arc fire now?
					blockArray.push(exprCall("onTraverse", [exprID("trigger")]));

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

		var funBlock = new Array<Expr>();

//		funBlock.push( macro if (_triggerQueue == null) trace("_triggerQueue is null???"));
		funBlock.push( macro _triggerQueue.push( trigger ));
		funBlock.push( macro if (_inTransition) return );
		funBlock.push( macro _inTransition = true );
	
		var swBlockArray = new Array<Expr>();


		for (i in 0...model.defaultStates.length) {
			var sw = Exprs.at(ESwitch(Exprs.at(EConst(CIdent("_state" + i))), stateCases, Exprs.at(EThrow(Exprs.at(EConst(CString("State not found")))))));
			swBlockArray.push(sw);
		}

		var swBlock = Exprs.at(EBlock(swBlockArray));

		funBlock.push( macro while (_triggerQueue.length > 0) { trigger = _triggerQueue.pop(); $swBlock; } );
	
		funBlock.push( macro _inTransition = false );


		var arg:FunctionArg = {name: "trigger", type: macro:Int};
		var fun:Function = {args: [arg], expr: Exprs.at(EBlock(funBlock))};

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

	// Tries to guess at correct overload
	static function exprCallField(f:Field, a : Expr, b : Expr = null, allowSingle : Bool = true) : Expr {

    switch(f.kind) {
        case FFun(fun):
			if (fun.args.length == 0) {
				return Exprs.call(Exprs.at(EConst(CIdent(f.name))), []);
			}
			if (fun.args.length == 1) {
				
				if (allowSingle) {
					var ct : ComplexType = fun.args[0].type;
					if (ComplexTypeTools.toString(fun.args[0].type ) == "sm.State") {
						return Exprs.call(Exprs.at(EConst(CIdent(f.name))), [a]);
					} else if (ComplexTypeTools.toString(fun.args[0].type ) == "sm.Transition") {
						return Exprs.call(Exprs.at(EConst(CIdent(f.name))), [b]);
					}
				}
				
				throw 'Unsupported parameter pattern on ${f.name}';				
			}
			if (fun.args.length == 2 && b != null) {
				return Exprs.call(Exprs.at(EConst(CIdent(f.name))), [a,b]);
			}

			throw 'Unsupported parameter pattern on ${f.name}';	
        default : throw "Not a function";
    }


	return null;
}

	static public function buildEventFunctions(cb:tink.macro.ClassBuilder, actions : ActionMaps, model:StateMachineModel, allowListeners : Bool) {

		var caseArray = new Array<Case>();
		var transitionExpr = exprID("transition");
		for (t in model.transitionNames) {
			var transitionNameExpr = exprID("T_" + t);

			var handlerArray = new Array<Expr>();
			if (actions.traverse.exists(t)) {
				for (a in actions.traverse[t])
					handlerArray.push(exprCallField(a,transitionNameExpr, transitionExpr));
				caseArray.push({values:[transitionNameExpr], expr: EBlock(handlerArray).at()});
			}

		}

		cb.addMember(makeMemberFunction("onTraverse", Functions.func(ESwitch(transitionExpr,caseArray,  null).at(), [Functions.toArg("transition", macro:Int)], null, null, false ), true));

		for (s in model.stateNames) {
			var stateNameExpr = exprID("S_" + s);
			var triggerExpr = exprID("trigger");
			var stateExpr = exprID("state");
			var handlerArray = new Array<Expr>();
			if (actions.entry.exists(s))
				for (a in actions.entry[s])
					handlerArray.push(exprCallField(a,stateNameExpr, triggerExpr));
			if (actions.entryBy.exists(s))
				for (a in actions.entryBy[s])
					handlerArray.push(isEmpty(a.b) ? exprCallField(a.a, stateNameExpr, triggerExpr) : exprIf(exprEq(triggerExpr, exprID("T_" + a.b)),  exprCallField(a.a,stateNameExpr, exprID("trigger"))));

			if (allowListeners) {
				var index = macro _listeners[i];
				var call = Exprs.at(EField(index, "onEnterBy" + s));
				handlerArray.push(exprFor(macro i, macro _listeners.length, macro $call( $stateNameExpr, trigger)));
			}
			cb.addMember(makeMemberFunction("onEnterBy" + s, Functions.func(Exprs.toBlock(handlerArray), [Functions.toArg("trigger", macro:Int)])));
			
			handlerArray.resize(0);
			if (actions.exit.exists(s))
				for (a in actions.exit[s])
					handlerArray.push(exprCallField(a,stateNameExpr, triggerExpr));
			if (allowListeners) {
				var call = Exprs.at(EField(macro _listeners[i], "onExit" + s));
				handlerArray.push(exprFor(macro i, macro _listeners.length, macro $call( $stateNameExpr, trigger)));
			}
			cb.addMember(makeMemberFunction("onExit" + s, Functions.func(Exprs.toBlock(handlerArray), [Functions.toArg("trigger", macro:Int)])));
			handlerArray.resize(0);
			if (actions.entryFrom.exists(s))
				for (a in actions.entryFrom[s])
					handlerArray.push(isEmpty(a.b) ? exprCallField(a.a, stateNameExpr,stateExpr, false) : exprIf(exprEq(exprID("state"), exprID("S_" + a.b)),  exprCallField(a.a,stateNameExpr,stateExpr, false)));
			if (allowListeners) {
				var call = Exprs.at(EField(macro _listeners[i], "onEnterFrom" + s));
				handlerArray.push(exprFor(macro i, macro _listeners.length, macro $call( $stateNameExpr, state)));
			}
			cb.addMember(makeMemberFunction("onEnterFrom" + s, Functions.func(Exprs.toBlock(handlerArray), [Functions.toArg("state", macro:Int)])));
		}
	}

	@:persistent static var _machines = new Map<String, StateMachineModel>();
	@:persistent static var _fileDates = new Map<String, Date>();

	static function getMachine(path:String, machine:String):StateMachineModel {
		var key = path + "_" + machine;
		var m = _machines.get(key);

		var stat:sys.FileStat = sys.FileSystem.stat(path);
		if (m != null && _fileDates.exists(path) && _fileDates[path].getUTCSeconds() == stat.mtime.getUTCSeconds()){
			return _machines.get(key);
		}
		var smArray = Visio.read(path);
		for (sm in smArray) {
			var key = path + "_" + sm.name;
			_machines[key] = sm;
		}
		_fileDates[path] = stat.mtime;
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

		var fields = new Array<Field>();

		for (s in model.stateNames) {
			var x:Function = {args: [Functions.toArg("trigger", macro:Int)]};

			fields.push(makeMemberFunction("onEnterBy" + s, {ret: macro:Void, args: [Functions.toArg("state", macro:Int), Functions.toArg("trigger", macro:Int)]}));
			fields.push(makeMemberFunction("onExit" + s, {ret: macro:Void, args: [Functions.toArg("state", macro:Int), Functions.toArg("trigger", macro:Int)]}));
			fields.push(makeMemberFunction("onEnterFrom" + s, {ret: macro:Void, args: [Functions.toArg("from", macro:Int), Functions.toArg("to", macro:Int)]}));
		}

		Context.defineType({
			pack: Context.getLocalClass().get().pack,
			name: getInterfaceName(),
			pos: Context.currentPos(),
			kind: TDClass(null, null, true),
			fields: fields
		});

		return [];
	}

	static function buildConstructor(cb:tink.macro.ClassBuilder, model:StateMachineModel) {
		var con = cb.getConstructor();

		con.init("_state0", Context.currentPos(), Value(exprID("S_" + model.defaultStates[0])));
		con.publish();
	}

	static function buildInitFunction(cb:tink.macro.ClassBuilder,  actions : ActionMaps, model:StateMachineModel) {

		var xx = exprID("S_" + model.defaultStates[0]);

		var blockList = new Array<Expr>();
		//manual initialization due to weird network hxbit behaviour
		blockList.push((macro _state0 = $xx));
		blockList.push(macro _triggerQueue = new List<Int>() );
		blockList.push(macro _inTransition = false );
		
		if (actions.entry.exists(model.defaultStates[0])) {
			var stateNameExpr = exprID("S_" + model.defaultStates[0]);
			for (a in actions.entry[model.defaultStates[0]])
				blockList.push(exprCallField(a,stateNameExpr));
		}

		var ff = EBlock(blockList).at().func([], false);
		cb.addMember( makeMemberFunction("__state_init", ff) );

//		con.init("_state0", Context.currentPos(), Value(exprID("S_" + model.defaultStates[0])));
//		con.publish();
	}

	macro static public function build(path:String, machine:String, makeInterface:Bool, constructor:Bool, print:Bool):Array<Field> {

		//trace("Building state machine " + Context.getLocalClass().get().name);

		var model = getMachine(path, machine);

		var cb = new tink.macro.ClassBuilder();

		buildConstants(cb, model);
		buildVars(cb, model, makeInterface);

		var actions = getActions();

		buildEventFunctions(cb, actions, model, makeInterface);
		buildFireFunction(cb, model);
		buildIsInFunction(cb, model);
		buildFireStrFunction(cb, model);

		if (makeInterface) {
			buildInterface(path, machine);
		}

		if (constructor) {
			buildConstructor(cb, model);
		} else {
			buildInitFunction(cb, actions, model);
		}

		
		return cb.export(print);
	}

	macro static public function print():Array<Field> {
		trace(_printer.printComplexType(Context.getLocalType().toComplex()));
		return [];
	}

	macro static public function overlay(path:String, machine:String, print:Bool):Array<Field> {
		var cb = new tink.macro.ClassBuilder();
		var model = getMachine(path, machine);

		return cb.export(print);
	}
}
#end
