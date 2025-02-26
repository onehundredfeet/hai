package ai.sm.macro;

#if macro
import haxe.macro.ComplexTypeTools;
import haxe.macro.Printer;
import haxe.macro.Context;
import haxe.macro.Expr;
import ai.macro.MacroTools;
import grph.NodeGraph;
import grph.NodeDocReader;
import grph.NodeGraphReader;
import sys.FileSystem;
import haxe.Exception;

using ai.macro.Extensions;
using StringTools;
using Lambda;
using haxe.macro.TypeTools;

typedef NodeGraphNode = grph.Node;

typedef StateAction = {
	entries:Array<String>,
	exits:Array<String>,
	entrybys:Array<String>,
	entryfroms:Array<String>
}

typedef FieldTransition = {
	field:Field,
	transition:String
}

typedef ActionMaps = {
	entry:Map<String, Array<Field>>,
	traverse:Map<String, Array<Field>>,
	entryBy:Map<String, Array<FieldTransition>>,
	entryFrom:Map<String, Array<FieldTransition>>,
	exit:Map<String, Array<Field>>,
	globalEntry:Array<Field>,
	globalExit:Array<Field>,
	whiles:Map<String, Array<Field>>
}

class ExternalSM {
	static function makeFinalInt(n:String, v:Int, ?t:ComplexType) {
		var newField = {
			name: n,
			doc: null,
			meta: [],
			access: [AStatic, APublic, AFinal],
			kind: FVar((t == null) ? (macro :Int) : t, v.toExpr()),
			pos: Context.currentPos()
		};

		return newField;
	}

	static function makeVarInt(n:String, v:Int, ?t:ComplexType) {
		var newField = {
			name: n,
			doc: null,
			meta: [],
			access: [],
			kind: FVar(null, v.toExpr()),
			pos: Context.currentPos()
		};

		return newField;
	}

	static function isEmpty(s:String) {
		if (s == null)
			return true;
		if (s.length == 0)
			return true;

		return false;
	}

	static function makeMemberFunction(n:String, f:Function, access:Array<Access>):Field {
		var func = {
			name: n,
			doc: null,
			meta: [],
			access: access,
			kind: FFun(f),
			pos: Context.currentPos()
		};
		return func;
	}

	static function gatherTimerNames() {
		var timerNames = [];

		for (f in Context.getBuildFields()) {
			var mmap = f.meta.toMap();
			if (mmap.exists(":after")) {
				timerNames.push(f.name);
			}
		}

		return timerNames;

	}
	static function buildConstantFields( model:NodeGraph) : Array<Field> {
		var count = 0;
		var fields = [];
		for (ss in model.nodes) {
			fields.push(makeFinalInt(getNameEnumStateName(ss.name), count++, macro :ai.sm.State));
			//            trace("State name:" + ss);
		}
		count = 0;
		var transitionNames = model.gatherOutgoingRelationNames();

		for (ss in transitionNames) {
			if (isEmpty(ss)) {
				trace('Transition names ${transitionNames}');
				Context.fatalError('Empty transition name', Context.currentPos());
			}
			fields.push(makeFinalInt("T_" + ss, count++, macro :ai.sm.Transition));
			//            trace("State name:" + ss);
		}
		return fields;
	}






	// static function buildConstantFields( model:NodeGraph) : Array<Field> {
	// 	var count = 0;
	// 	var fields = [];
	// 	for (ss in model.nodes) {
	// 		fields.push(makeFinalInt(getNameEnumStateName(ss), count++, macro :ai.sm.State));
	// 		//            trace("State name:" + ss);
	// 	}
	// 	count = 0;
	// 	var transitionNames = model.gatherOutgoingRelationNames();

	// 	for (ss in transitionNames) {
	// 		if (isEmpty(ss)) {
	// 			trace('Transition names ${transitionNames}');
	// 			Context.fatalError('Empty transition name', Context.currentPos());
	// 		}
	// 		fields.push(makeFinalInt("T_" + ss, count++, macro :ai.sm.Transition));
	// 		//            trace("State name:" + ss);
	// 	}
	// 	return fields;
	// }



	static var _printer = new haxe.macro.Printer();

	static function getStateEnumName() {
		return "E" + Context.getLocalClass().get().name + "State";
	}

	static function buildStateEnum( model:NodeGraph) {
		var fields = [];

		var count = 0;
		for (ss in model.nodes) {
			fields.push(makeVarInt(getNameEnumStateName(ss.name), count++));
		}

		var def = {
			pack: Context.getLocalClass().get().pack,
			name: getStateEnumName(),
			pos: Context.currentPos(),
			kind: TDAbstract(macro :Int, [AbEnum]),
			fields: fields
		};

		trace(_printer.printTypeDefinition(def));

		Context.defineType(def);
	}

	static function getTransitionEnumName() {
		return "E" + Context.getLocalClass().get().name + "Transition";
	}

	static function buildTransitionEnum( model:NodeGraph) {
		var fields = [];

		var transitionNames = model.gatherOutgoingRelationNames();
		var count = 0;
		

		for (ss in transitionNames) {
			if (isEmpty(ss)) {
				trace('Transition names ${transitionNames}');
				Context.fatalError('Empty transition name', Context.currentPos());
			}
			fields.push(makeVarInt(getNameEnumTransitionName(ss), count++));
			//            trace("State name:" + ss);
		}


		var def = {
			pack: Context.getLocalClass().get().pack,
			name: getTransitionEnumName(),
			pos: Context.currentPos(),
			kind: TDAbstract(macro :Int, [AbEnum]),
			fields: fields
		};

		trace(_printer.printTypeDefinition(def));

		Context.defineType(def);
	}


	static function externalStateClassName() {
		return Context.getLocalClass().get().name + "State";
	}
	static function buildExternalStateClass( model:NodeGraph) {
		var fields = [];
		var ds = getDefaultState(model);

		var enumName = getStateEnumName();
		var enumCT = enumName.asComplexType();

		var transitionEnumName = getTransitionEnumName();
		var transitionEnumCT = transitionEnumName.asComplexType();
		
		fields.push(buildConstructor(model));

		fields.push({
			name: "state",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FVar(enumCT, EConst(CIdent(getNameEnumStateName(ds.name))).at()),
			pos: Context.currentPos()
		});

		fields.push({
			name: "lastState",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FVar(enumCT, EConst(CIdent(getNameEnumStateName(ds.name))).at()),
			pos: Context.currentPos()
		});

		fields.push({
			name: "lastTransition",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FVar(transitionEnumCT, null),
			pos: Context.currentPos()
		});
		
		fields.push({
			name: "inTransition",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FVar(macro :Bool, macro false),
			pos: Context.currentPos()
		});

		fields.push({
			name: "triggerQueue",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FVar(macro :Array<$transitionEnumCT>, macro []),
			pos: Context.currentPos()
		});

		fields.push({
			name: "lastUpdateTime",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FVar(macro :Float),
			pos: Context.currentPos()
		});

		fields.push({
			name: "lastTransitionTime",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FVar(macro :Float),
			pos: Context.currentPos()
		});

		// for (t in timers) {
		// 	fields.push({
		// 		name: "timer_" + t,
		// 		doc: null,
		// 		meta: [],
		// 		access: [APublic],
		// 		kind: FVar(macro :Float),
		// 		pos: Context.currentPos()
		// 	});
		// }

		fields.push(buildIsInFunction( model));
		fields.push(buildQueueFunction( model));

		var def = {
			pack: Context.getLocalClass().get().pack,
			name: externalStateClassName(),
			pos: Context.currentPos(),
			kind: TDClass(),
			fields: fields
		};

		trace(_printer.printTypeDefinition(def));

		Context.defineType(def);
		//return fields;
	}
	

	
	static function buildMachineClass( model:NodeGraph, actions:ActionMaps, ticking:Bool, timers : Array<String>) {

	}

	static function buildVars( model:NodeGraph, actions:ActionMaps, allowListeners:Bool, signals:Bool, ticking:Bool, timers : Array<String>) : Array<Field> {
		var fields = [];

		var count = 0;
		var defaultStates = [getDefaultState(model)];
		for (ds in defaultStates) {
			var stateField = {
				name: "_state" + count,
				doc: null,
				meta: [],
				access: [APrivate],
				kind: FVar(macro :Int, EConst(CIdent(getNameEnumStateName(ds.name))).at()),
				pos: Context.currentPos()
			};

			fields.push(stateField);
		}

		fields.push("state".prop( macro :Int, Context.currentPos(), false, true));
		fields.push("state".getter( null, macro _state0, macro :Int));
		fields.push("stateName".prop( macro :String, Context.currentPos(), false, true));

		var cases = new Array<Case>();

		for (i in 0...model.nodes.length) {
			var c:Case = {values: [exprConstInt(i)], expr: exprRet(exprConstString(model.nodes[i].name))};
			cases.push(c);
		}

		var throwExpr = macro throw 'State not found ${_state0}';

		var sw =ESwitch(EConst(CIdent("_state0")).at(), cases, throwExpr).at();
		fields.push("stateName".getter( null, sw, macro :String));

		// if (allowListeners) {
		// 	var ct = getInterfaceName().asComplexType();
		// 	var listeneners = {
		// 		name: "_listeners",
		// 		doc: null,
		// 		meta: [],
		// 		access: [APrivate],
		// 		kind: FVar("Array".asComplexType( [TPType(ct)]), ENew("Array".asTypePath( [TPType(ct)]), []).at()),
		// 		pos: Context.currentPos()
		// 	};

		// 	fields.push(listeneners);

		// 	fields.push(makeMemberFunction("addListener", (macro _listeners.push(l)).func( ["l".toArg( ct)]), []));
		// }

		if (ticking) {
			for (f in Context.getBuildFields()) {
				var mmap = f.meta.toMap();
				if (mmap.exists(":after")) {
					var n = "__timer_" + f.name;
					var timerMember = {
						name: n,
						doc: null,
						meta: [],
						access: [APrivate],
						kind: FVar(macro :Float),
						pos: Context.currentPos()
					};

					fields.push(timerMember);
					timers.push(n);
				}
			}

			var timerMember = {
				name: "__state_now",
				doc: null,
				meta: [],
				access: [APrivate],
				kind: FVar(macro :Float),
				pos: Context.currentPos()
			};

			fields.push(timerMember);
		}
		return fields;
	}

	static function cleanState(s:String):String {
		if (s.startsWith("S_")) {
			return s.substr(2).toUpperCase();
		}
		return s.toUpperCase();
	}

	static function cleanIdentifier(s:String):String {
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
				var state = p.getIdent();

				if (state != null) {
					var stateName = cleanIdentifier(state);
					if (!map.exists(stateName))
						map[stateName] = new Array<Field>();
					map[stateName].push(f);
				}
			}
		}
	}

	static function addGlobals(array:Array<Field>, meta:Array<Array<Expr>>, f:Field) {
		if (meta == null)
			return;
		for (se in meta) {
			if (se.length == 0)
				array.push(f);
		}
	}

	static function addConditionalActions(map:Map<String, Array<FieldTransition>>, meta:Array<Array<Expr>>, f:Field) {
		if (meta == null)
			return;
		for (se in meta) {
			if (se.length >= 1) {
				var state = se[0].getIdent();
				if (state != null) {
					var stateName = cleanState(state);

					if (!map.exists(stateName))
						map[stateName] = new Array<FieldTransition>();

					if (se.length >= 2 && se[1].getIdent() != null) {
						map[stateName].push({field: f, transition: se[1].getIdent()});
					} else {
						map[stateName].push({field: f, transition: null});
					}
				}
			}
		}
	}

	static function getActions():ActionMaps {
		var entryMap = new Map<String, Array<Field>>();
		var traverseMap = new Map<String, Array<Field>>();
		var entryByMap = new Map<String, Array<FieldTransition>>();
		var entryFromMap = new Map<String, Array<FieldTransition>>();
		var exitMap = new Map<String, Array<Field>>();
		var entryGlobals = new Array<Field>();
		var exitGlobals = new Array<Field>();
		var whileMap = new Map<String, Array<Field>>();
		//		trace('Examining: ${Context.getLocalClass().get().name}');
		//		trace('Num Fields: ${Context.getLocalClass().get().fields.get().length}');
		//		trace('Build Fields: ${Context.getBuildFields().length}');
		for (field in Context.getBuildFields()) {
			var mmap = field.meta.toMap();

			var whilesMeta = field.meta.getValues(":while");
			var hasWhile = whilesMeta != null && whilesMeta.length > 0;
			var whiles = whilesMeta.map((x) -> if (x != null) x.map((y) -> y.getIdent()) else []).flatten();
			var whileStr = if (hasWhile) "while " + whiles else "";

			switch (field.kind) {
				case FFun(fun):
					//					var enter = mmap.get(":enter");

					addActions(traverseMap, mmap.get(":traverse"), field);
					addActions(entryMap, mmap.get(":enter"), field);
					addActions(exitMap, mmap.get(":exit"), field);
					addActions(whileMap, mmap.get(":while"), field);
					addGlobals(entryGlobals, mmap.get(":enter"), field);
					addGlobals(exitGlobals, mmap.get(":exit"), field);
					addConditionalActions(entryByMap, mmap.get(":enterby"), field);
					addConditionalActions(entryFromMap, mmap.get(":enterfrom"), field);
				default:
					continue;
			}
		}

		return {
			entry: entryMap,
			traverse: traverseMap,
			entryBy: entryByMap,
			entryFrom: entryFromMap,
			exit: exitMap,
			globalExit: exitGlobals,
			globalEntry: entryGlobals,
			whiles: whileMap
		};
	}

	static function isValidLeafNode(n:NodeGraphNode) {
		if (n.hasChildren())
			return false;
		if (n.name == null)
			return false;
		return true;
	}

	static function buildProcessFunction( stateClassCT : ComplexType, graph:NodeGraph) {
		var stateCases = new Array<Case>();

		var stateEnumName = getStateEnumName();
		var stateEnumCT = stateEnumName.asComplexType();

		var transitionEnumName = getTransitionEnumName();
		var transitionEnumCT = transitionEnumName.asComplexType();


		for (currentNode in graph.nodes) {
			if (!isValidLeafNode(currentNode))
				continue;
			var triggers = new Map<String, Bool>();
			var triggerCases = new Array<Case>();

			//trace('Walking all triggers here and up ${currentNode.name}');
			var s = currentNode;
			while (s != null) {
				//trace('\tWalking node ${currentNode.name} : ${s.name}');
				var parent = s.parent;
				s.walkOutgoingEdgesNonChildren((trigger) -> {
					var targetState = trigger.target;
					var sourceStateName = s.name;
					var targetStateName = targetState.name;

					//trace('\t\tWalking transition ${sourceStateName} -> ${trigger.name} -> ${targetStateName}');

					if (triggers.exists(trigger.name)) {
						Context.fatalError('Overlapping triggers ${trigger} on ${currentNode.name}', Context.currentPos());
					} else {
						triggers.set(trigger.name, true);
					}

					var blockArray = new Array<Expr>();

					var exited = new Array<String>();
					exited.push(currentNode.name);
					blockArray.push(exprCall("onExit" + currentNode.name, [exprID("self"), exprID("trigger")]));
					//trace('\t\tBuilding on exit ${currentNode.name} by ${trigger.name} ');

					var leafState = getInitialLeaf(targetState);
					var leafStateName = leafState.name;

					var commonRoot = s.firstCommonAncestor(leafState);
					var parent = currentNode.parent; //s.parent;

					while (parent != commonRoot && parent != null) {
						var pName = parent.name;
						blockArray.push(exprCall("onExit" + pName, [exprID("self"), exprID("trigger")]));
						//trace('\t\t\tAdding exit ${pName}');

						exited.push(pName);
						parent = parent.parent;
					}

					// Does the arc fire now?
					blockArray.push(exprCall("onTraverse", [exprID("self"), exprID("trigger")]));

					var walkList = new Array<NodeGraphNode>();

					parent = leafState.parent;
					while (parent != commonRoot && parent != null) {
						walkList.push(parent);
						parent = parent.parent;
					}

					walkList.reverse();

					for (targetAncestor in walkList) {
						for (exit in exited) {
							blockArray.push(exprCall("onEnterFrom" + targetAncestor.name, [exprID("self"), exprID(getNameEnumStateName(exit))]));
						}
						blockArray.push(exprCall("onEnterBy" + targetAncestor.name, [exprID("self"), exprID(trigger.name)]));
					}
					
					blockArray.push(makeMemberAccessExpr("self", "lastState").assign( makeMemberAccessExpr("self", "state")));
					blockArray.push(makeMemberAccessExpr("self", "state").assign( exprID(getNameEnumStateName(leafStateName))));

					for (exit in exited) {
						blockArray.push(exprCall("onEnterFrom" + leafStateName, [exprID("self"), exprID(getNameEnumStateName(exit))]));
					}

					blockArray.push(exprCall("onEnterBy" + leafStateName, [exprID("self"), exprID(trigger.name)]));
					var tc:Case = {values: [makeMemberAccessExpr(transitionEnumName, trigger.name)], expr: blockArray.toBlock()};
					triggerCases.push(tc);
				});
				s = parent;
			}

			var triggerSwitch = ESwitch(EConst(CIdent("trigger")).at(), triggerCases, EBlock([]).at()).at();

			var stateCasec:Case = {values: [makeMemberAccessExpr(stateEnumName, getNameEnumStateName(currentNode.name))], expr: triggerSwitch};
			stateCases.push(stateCasec);
		}

		var funBlock = new Array<Expr>();

		//		funBlock.push( macro if (_triggerQueue == null) trace("_triggerQueue is null???"));
//		funBlock.push(macro self.triggerQueue.push(trigger));
		// funBlock.push(macro if (self.inTransition)
		// 	return);
//		funBlock.push(macro self.inTransition = true);

		var swBlockArray = new Array<Expr>();

		//var defaultState = getDefaultState(graph);

		var sw = ESwitch(makeMemberAccessExpr("self", "state"), stateCases, EThrow(EConst(CString("State not found")).at()).at()).at();
		swBlockArray.push(sw);

		var swBlock = EBlock(swBlockArray).at();

		funBlock.push(macro while (self.triggerQueue.length > 0) {
			var trigger = self.triggerQueue.shift();
			$swBlock;
		});

//		funBlock.push(macro self.inTransition = false);

		var argClass: FunctionArg = {name: "self", type: stateClassCT};
//		var arg:FunctionArg = {name: "trigger", type: macro :Int};
		var fun:Function = {args: [argClass], expr: EBlock(funBlock).at()};

		var fireFunc = {
			name: "process",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FFun(fun),
			pos: Context.currentPos()
		};

		return fireFunc;
	}

	static function buildIsInFunction( model:NodeGraph) {
		var blockArray = new Array<Expr>();

		blockArray.push(exprIf(exprEq(exprID("state"), exprID("inState")), macro return true));

		var cases = new Array<Case>();

		for (s in model.nodes) {
			if (!isValidLeafNode(s))
				continue;

			var subcases = new Array<Case>();
			var parent = s.parent;

			while (parent != null) {
				var c:Case = {values: [exprID( getNameEnumStateName(parent.name))], expr: macro return true};
				subcases.push(c);

				parent = parent.parent;
			}

			var caseExpr = subcases.length > 0 ? ESwitch(exprID("state"), subcases, EBlock([]).at()).at() : macro return false;

			var theCase:Case = {values: [EConst(CIdent(getNameEnumStateName(s.name))).at()], expr: caseExpr};
			cases.push(theCase);
		}

		var throwExpr = macro throw 'State not found ${state}';
		var sw = ESwitch(EConst(CIdent("state")).at(), cases, throwExpr).at();

		blockArray.push(sw);
		blockArray.push(macro return false);

		var enumName = getStateEnumName();
		var enumCT = enumName.asComplexType();

		return {
			name: "isIn",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FFun({args: [{name: "inState", type: enumCT}], expr: EBlock(blockArray).at()}),
			pos: Context.currentPos()
		};
	}

	static function buildQueueFunction( model:NodeGraph) {
		var enumName = getTransitionEnumName();
		var enumCT = enumName.asComplexType();
		return {
			name: "queue",
			doc: null,
			meta: [],
			access: [APublic, AInline],
			kind: FFun({args: [{name: "transition", type: enumCT}], expr: macro triggerQueue.push(transition)}),
			pos: Context.currentPos()
		};
	}

	static function buildFireStrFunction( graph:NodeGraph) {
		var cases = new Array<Case>();

		var transitionNames = graph.gatherOutgoingRelationNames();
		for (t in transitionNames) {
			var c:Case = {values: [exprConstString(t)], expr:ECall(EConst(CIdent("fire")).at(), [EConst(CIdent("T_" + t)).at()]).at()};
			cases.push(c);
		}

		var sw = ESwitch(EConst(CIdent("trigger")).at(), cases, EThrow(EConst(CString("Trigger not found")).at()).at()).at();

		var arg:FunctionArg = {name: "trigger", type: macro :String};
		var fun:Function = {args: [arg], expr: sw};

		var fireFunc = {
			name: "fireStr",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FFun(fun),
			pos: Context.currentPos()
		};

		return fireFunc;
	}

	// Tries to guess at correct overload
	static function exprCallField(f:Field, stateExpr:Expr, transExpr:Expr = null, allowSingle:Bool = true):Expr {
		var stateEnumName = getStateEnumName();
		var stateEnumCT = stateEnumName.asComplexType();

		var transitionEnumName = getTransitionEnumName();
		var transitionEnumCT = transitionEnumName.asComplexType();

		var stateClassStr = externalStateClassName();
		var stateClassCT = stateClassStr.asComplexType();
		
		switch (f.kind) {
			case FFun(fun):

			var mappedArgs = fun.args.map((x) -> {
				var ct = x.type;
				if (ComplexTypeTools.toString(ct) == stateEnumName) {
					return stateExpr;
				} else if (ComplexTypeTools.toString(ct) == transitionEnumName) {
					return transExpr;
				} else if (ComplexTypeTools.toString(ct) == stateClassStr) {
					return exprID( "self");
				} else {
					return null;
				}
			});

			return EConst(CIdent(f.name)).at().call( mappedArgs);
				// if (fun.args.length == 0) {
				// 	return EConst(CIdent(f.name)).at().call( []);
				// }
				// if (fun.args.length == 1) {
				// 	if (allowSingle) {
				// 		var ct:ComplexType = fun.args[0].type;
				// 		if (ComplexTypeTools.toString(fun.args[0].type) == "ai.sm.State") {
				// 			return EConst(CIdent(f.name)).at().call( [exprID( "self"), a]);
				// 		} else if (ComplexTypeTools.toString(fun.args[0].type) == "ai.sm.Transition") {
				// 			return EConst(CIdent(f.name)).at().call( [exprID( "self"), b]);
				// 		}
				// 	}

				// 	throw 'Unsupported parameter pattern on ${f.name}';
				// }
				// if (fun.args.length == 2 && b != null) {
				// 	return EConst(CIdent(f.name)).at().call( [exprID( "self"), a, b]);
				// }

				throw 'Unsupported parameter pattern on ${f.name}';
			default:
				throw "Not a function";
		}

		return null;
	}

	static public function buildEventFunctions( actions:ActionMaps, model:NodeGraph,ticking:Bool) {
		var stateEnumName = getStateEnumName();
		var stateEnumCT = stateEnumName.asComplexType();

		var transitionEnumName = getTransitionEnumName();
		var transitionEnumCT = transitionEnumName.asComplexType();

		var stateClassStr = externalStateClassName();
		var stateClassCT = stateClassStr.asComplexType();

		var fields = [];
		var caseArray = new Array<Case>();
		var transitionExpr = exprID("transition");
		var transitionNames = model.gatherOutgoingRelationNames();
		for (t in transitionNames) {
			var transitionNameExpr = exprID( t);

			var handlerArray = new Array<Expr>();
			if (actions.traverse.exists(t)) {
				for (a in actions.traverse[t])
					handlerArray.push(exprCallField(a, transitionNameExpr, transitionExpr));
				caseArray.push({values: [transitionNameExpr], expr: EBlock(handlerArray).at()});
			}
		}

		fields.push(makeMemberFunction("onTraverse",
		EBlock([
			macro self.lastTransitionTime = nowTime,
			macro self.lastTransition = transition,
			ESwitch(transitionExpr, caseArray, null).at()]).at().func( ["self".toArg(stateClassCT), "transition".toArg(transitionEnumCT)], null, null, false), [AInline, AFinal]));

		for (n in model.nodes) {
			var s = n.name;
			var stateNameExpr = exprID(getNameEnumStateName(s));
			var triggerExpr = exprID("trigger");
			var stateExpr = exprID("state");
			var handlerArray = new Array<Expr>();
			if (actions.entry.exists(s))
				for (a in actions.entry[s])
					handlerArray.push(exprCallField(a, stateNameExpr, triggerExpr));
			if (actions.entryBy.exists(s))
				for (a in actions.entryBy[s])
					handlerArray.push(isEmpty(a.transition) ? exprCallField(a.field, stateNameExpr,
						triggerExpr) : exprIf(exprEq(triggerExpr, exprID("T_" + a.transition)), exprCallField(a.field, stateNameExpr, exprID("trigger"))));

			// if (allowListeners) {
			// 	var index = macro _listeners[i];
			// 	var call = EField(index, "onEnterBy" + s).at();
			// 	handlerArray.push(exprFor(macro i, macro _listeners.length, macro $call($stateNameExpr, trigger)));
			// }

			for (ge in actions.globalEntry) {
				handlerArray.push(exprCallField(ge, stateNameExpr, triggerExpr));
			}

			// if (signals) {
			// 	var sigName = "sig" + s;
			// 	var x = macro $i{sigName}.dispatch($i{"S_" + s}, trigger, true);
			// 	handlerArray.push(x);
			// }

			if (ticking) {
				var whiles = actions.whiles.get(s);
				if (whiles != null) {
					var whileArray = new Array<Expr>();
					for (w in whiles) {
						var mm = w.meta.toMap();
						if (mm.exists(":after")) {
							// var tname = "__timer_" + w.name;
							// handlerArray.push(macro $i{tname} = __state_now);
						}
					}
				}
			}

			fields.push(makeMemberFunction("onEnterBy" + s, handlerArray.toBlock().func( ["self".toArg(stateClassCT), "trigger".toArg(transitionEnumCT)]),
				[AInline, AFinal]));

			handlerArray.resize(0);
			if (actions.exit.exists(s))
				for (a in actions.exit[s])
					handlerArray.push(exprCallField(a, stateNameExpr, triggerExpr));
			// if (allowListeners) {
			// 	var call = EField(macro _listeners[i], "onExit" + s).at();
			// 	handlerArray.push(exprFor(macro i, macro _listeners.length, macro $call($stateNameExpr, trigger)));
			// }
			// if (signals) {
			// 	var sigName = "sig" + s;
			// 	var x = macro $i{sigName}.dispatch($i{"S_" + s}, trigger, false);
			// 	handlerArray.push(x);
			// }
			fields.push(makeMemberFunction("onExit" + s, handlerArray.toBlock().func( ["self".toArg(stateClassCT), "trigger".toArg( transitionEnumCT)]),
				[AInline, AFinal]));
			handlerArray.resize(0);
			if (actions.entryFrom.exists(s))
				for (a in actions.entryFrom[s])
					handlerArray.push(isEmpty(a.transition) ? exprCallField(a.field, stateNameExpr, stateExpr,
						false) : exprIf(exprEq(exprID("state"), exprID(getNameEnumStateName(a.transition))), exprCallField(a.field, stateNameExpr, stateExpr, false)));
			// if (allowListeners) {
			// 	var call = EField(macro _listeners[i], "onEnterFrom" + s).at();
			// 	handlerArray.push(exprFor(macro i, macro _listeners.length, macro $call($stateNameExpr, state)));
			// }

			fields.push(makeMemberFunction("onEnterFrom" + s, handlerArray.toBlock().func(["self".toArg(stateClassCT), "state".toArg( stateEnumCT)]),
				[AInline, AFinal]));
		}
		return fields;
	}

	@:persistent static var _machines = new Map<String, NodeGraph>();
	@:persistent static var _fileDates = new Map<String, Date>();

	static function getGraph(path:String, machine:String):NodeGraph {
		if (path == null) Context.fatalError("Path cannot be null", Context.currentPos());

			var key = path + "_" + machine;
		var m = _machines.get(key);
		var stat:sys.FileStat = sys.FileSystem.stat(path);
		if (m != null && _fileDates.exists(path) && _fileDates[path].getUTCSeconds() == stat.mtime.getUTCSeconds()) {
			return _machines.get(key);
		}
		var nodeDoc = NodeDocReader.loadPath(path);
		for (p in nodeDoc) {
			var key = path + "_" + p.name;
			_machines[key] = NodeGraphReader.fromPage(p);
		}
		_fileDates[path] = stat.mtime;
		m = _machines.get(key);
		if (m == null) {
			throw 'No machine ${machine} found in ${path}';
		}
		return m;
	}


	static function initialChild(node:NodeGraphNode) {
		return node.getChildrenNodes().find((x) -> x.properties.exists('initial'));
	}

	static function getInitialLeaf(node:NodeGraphNode) {
		if (node.hasChildren()) {
			var x = node.getChildrenNodes().find((x) -> x.properties.exists('initial'));
			if (x != null)
				return getInitialLeaf(x);
			throw('No initial state for node ${node.name}');
		}
		return node;
	}

	static function getNameEnumStateName(name:String) {
		return /*"S_" + */ name.toUpperCase();
	}
	static function getNameEnumTransitionName(name:String) {
		return /*"T_" +*/ name.toUpperCase();
	}

	static function getDefaultState(graph:NodeGraph) {
		var defaultState = graph.nodes.find((x) -> x.properties.exists("default") || x.properties.exists("root") && x.getParent() == null);
		if (defaultState == null)
			Context.fatalError('No default state in graph', Context.currentPos());
		var defaultName = defaultState.name;

		var leafState = defaultState;
		var lastLeafState = leafState;

		while ((leafState = initialChild(leafState)) != null) {
			lastLeafState = leafState;
		}

		return lastLeafState;
	}

	static function getDefaultStateName(graph:NodeGraph) {
		return getNameEnumStateName(getDefaultState(graph).name);
	}

	static function buildConstructor( model:NodeGraph) {
		var func = {
			name: "new",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FFun({args: [], expr: macro {}, ret:null}),
			pos: Context.currentPos()
		};
		return func;
	}

	static function buildInitFunction( actions:ActionMaps, graph:NodeGraph, ticking:Bool, timers:Array<String>) {
		var xx = exprID(getDefaultStateName(graph));

		var blockList = new Array<Expr>();
		// manual initialization due to weird network hxbit behaviour
		blockList.push((macro _state0 = $xx));
		blockList.push(macro _triggerQueue = new Array<Int>());
		blockList.push(macro _inTransition = false);

		var curState = getDefaultState(graph).root();
		while (curState != null) {
			if (actions.entry.exists(curState.name)) {
				var stateNameExpr = exprID(getNameEnumStateName(curState.name));
				for (a in actions.entry[curState.name])
					blockList.push(exprCallField(a, stateNameExpr));
			}

			if (curState.hasChildren()) {
				curState = initialChild(curState);
			} else {
				curState = null;
			}
		}

		if (ticking) {
			for (t in timers) {
				blockList.push(macro $i{t} = time);
			}
			blockList.push(macro __state_now = time);
		}

		var ff = EBlock(blockList).at().func(ticking ? ["time".toArg(macro :Float)] : [], false);
		return makeMemberFunction("__state_init", ff, [AFinal]);
	}

	static function buildResetFunction( actions:ActionMaps, model:NodeGraph, ticking:Bool, timers:Array<String>) {
		var defStateName = getDefaultStateName(model);
		var xx = exprID(defStateName);

		var blockList = new Array<Expr>();
		// manual initialization due to weird network hxbit behaviour
		blockList.push((macro _state0 = $xx));
		blockList.push(macro _triggerQueue.resize(0));
		blockList.push(macro _inTransition = false);

		if (actions.entry.exists(defStateName)) {
			var stateNameExpr = exprID(defStateName);
			for (a in actions.entry[defStateName])
				blockList.push(exprCallField(a, stateNameExpr));
		}

		if (ticking) {
			for (t in timers) {
				blockList.push(macro $i{t} = time);
			}
			blockList.push(macro __state_now = time);
		}
		var ff = EBlock(blockList).at().func(ticking ? ["time".toArg(macro :Float)] : [], false);
		return makeMemberFunction("__state_reset", ff, [AFinal]);

		//		con.init("_state0", Context.currentPos(), Value(exprID("S_" + model.defaultStates[0])));
		//		con.publish();
	}

	static function buildTickFunction( model:NodeGraph, actions:ActionMaps) {
		var whiles = actions.whiles;
		var caseList = new Array<Case>();

		var stateEnumName = getStateEnumName();
		var stateEnumCT = stateEnumName.asComplexType();

		var transitionEnumName = getTransitionEnumName();
		var transitionEnumCT = transitionEnumName.asComplexType();

		var stateClassStr = externalStateClassName();
		var stateClassCT = stateClassStr.asComplexType();

		for (sn in model.nodes) {
			if (sn.hasChildren())
				continue;
			var cur = sn;
			var blockList = new Array<Expr>();

			while (cur != null) {
				var sname = cur.name;
				var ws = whiles.get(sname);
				if (ws != null) {
					var stateName = sname;
					var fcalls = ws.map(function(f) {
						var mm = f.meta.toMap();
						var calle = exprID(f.name).call([exprID("self")]);

						var ae = mm.get(":after");

						if (ae != null && ae.length > 0) {
							var cond = mm.get(":after").flatten()[0];
							var timerID = exprID( "__timer_" + f.name);
							var test = macro (nowTime - self.lastTransitionTime > $cond);
							return macro if ($test) $calle;
						} else {
							return calle;
						}
					});

					for (fc in fcalls) {
						blockList.push(fc);
					}
				}
				cur = cur.getParent();
			}

			if (blockList.length > 0) {
				var ecase:Case = {values: [exprID(getNameEnumStateName(sn.name))], expr: macro $b{blockList}};
				caseList.push(ecase);
			}
		}

		var swblock = EBlock([
			macro self.lastUpdateTime = nowTime,
			ESwitch(makeMemberAccessExpr("self", "state"), caseList, macro {}).at()
		]).at();
		var ff = swblock.func(["self".toArg(stateClassCT), "delta".toArg(macro :Float), "time".toArg(macro :Float)], false);
		return makeMemberFunction("tick", ff, [AFinal]);
	}

	// Generates Functions:
	// Need to be called by implementing class
	// __state_init()
	// __state_reset()
	// @:sm_tick will change the generation to include the following
	// __state_init( time : Float)
	// __state_reset( time : Float)
	// __state_tick(delta:Float, time:Float)
	// __state_now : Float
	// Can be called by anyone
	// fire()
	// fireStr()
	// isIn()

	static function loadModel(path:String, machine:String) {
		if (FileSystem.exists(path) != true) {
			try {
				var contextRelPath = Context.resolvePath(path);
				if (FileSystem.exists(contextRelPath) != true) {
					Context.fatalError('Can\'t find file ${path} or ${contextRelPath} for state machine file - moddule ${Context.getLocalModule()}', Context.currentPos());
				}
				path = contextRelPath;
			} catch(e) {
				Context.fatalError('Can\'t find file ${path} for state machine file - moddule ${Context.getLocalModule()}', Context.currentPos());
			}
			
		}

		var model = getGraph(path, machine);
		return model;
	}

	static function buildEnums(model:NodeGraph) {
		buildStateEnum(model);
		buildTransitionEnum(model);
	}
	// macro static public function buildState(path:String, machine:String):Array<Field> {
	// 	var fields = Context.getBuildFields();

	// 	var model = loadModel(path, machine);
	// 	fields = fields.concat(buildExternalStateClass(model));

	// 	trace('Building state ${Context.getLocalClass().get().name}');
	// 	for (f in fields) {
	// 		trace(_printer.printField(f));
	// 	}

	// 	return fields;
	// }

	static function makeMemberAccessExpr( varName:String, memberName:String) : Expr {
		return EField(EConst(CIdent(varName)).at(), memberName).at();

	}
	macro static public function buildMachine( path:String, machine:String):Array<Field> {
		// trace("Building state machine " + Context.getLocalClass().get().name);
		var model = loadModel(path, machine);

		buildEnums(model);
		buildExternalStateClass(model);

		var stateClassStr = externalStateClassName();
		var stateClassCT = stateClassStr.asComplexType();
		

		var cm = Context.getLocalClass().get().meta.get().toMap();
		var debug = cm.exists(":sm_debug");
		var ticking = cm.exists(":sm_tick");

		var actions = getActions();
		var fields = Context.getBuildFields();
		fields.push(buildProcessFunction( stateClassCT, model));
		fields.push(buildConstructor(model));
		var eventFunctions  : Array<Field> = buildEventFunctions( actions, model, ticking);

		fields = fields.concat(eventFunctions);

		fields.push({
			name: "nowTime",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FVar(macro :Float, EConst(CFloat("0")).at()),
			pos: Context.currentPos()
		});

		fields.push({
			name: "deltaTime",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FVar(macro :Float, EConst(CFloat("0")).at()),
			pos: Context.currentPos()
		});

		if (ticking) {
			fields.push(buildTickFunction( model, actions));
		}

		//fields.push(buildIsInFunction( model));
#if false
		// var constantFields : Array<Field> = buildConstantFields( model);

		// var varFields : Array<Field> = buildVars( model, actions, makeInterface, signals, ticking, timers);

		var fields = Context.getBuildFields().concat(constantFields).concat(varFields).concat(eventFunctions);
		
		

		if (constructor) {
// /			buildConstructor( model);
		} else {
			fields.push(buildInitFunction( actions, model, ticking, timers));
		}

		fields.push(buildResetFunction( actions, model, ticking, timers));


		return fields;

		#end

		if (cm.exists(":sm_print")) {
			for (m in fields) {
				trace(_printer.printField(m));
			}
		}


		return fields;
	}

	macro static public function print():Array<Field> {
		trace(_printer.printComplexType(Context.getLocalType().toComplexType()));
		return [];
	}

}
#end
