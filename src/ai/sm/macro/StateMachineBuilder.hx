package ai.sm.macro;

#if macro
import haxe.macro.ComplexTypeTools;
import haxe.macro.Printer;
import haxe.macro.Context;
import haxe.macro.Expr;
import ai.macro.MacroTools;
import gdoc.NodeGraph;
import gdoc.NodeDocReader;
import gdoc.NodeGraphReader;
import sys.FileSystem;
import haxe.Exception;

using ai.macro.Extensions;
using StringTools;
using Lambda;
using haxe.macro.TypeTools;

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

class StateMachineBuilder {
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

	static function buildConstantFields( model:NodeGraph) : Array<Field> {
		var count = 0;
		var fields = [];
		for (ss in model.nodes) {
			fields.push(makeFinalInt(getNameEnumStateName(ss), count++, macro :ai.sm.State));
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

	static function buildVars( model:NodeGraph, actions:ActionMaps, allowListeners:Bool, signals:Bool, ticking:Bool, timers : Array<String>) : Array<Field> {
		var fields = [];

		fields.push({
			name: "_inTransition",
			doc: null,
			meta: [],
			access: [APrivate],
			kind: FVar(macro :Bool, macro false),
			pos: Context.currentPos()
		});

		fields.push({
			name: "_triggerQueue",
			doc: null,
			meta: [],
			access: [APrivate],
			kind: FVar(macro :Array<Int>, null),
			pos: Context.currentPos()
		});

		var count = 0;
		var defaultStates = [getDefaultState(model)];
		for (ds in defaultStates) {
			var stateField = {
				name: "_state" + count,
				doc: null,
				meta: [],
				access: [APrivate],
				kind: FVar(macro :Int, EConst(CIdent(getNameEnumStateName(ds))).at()),
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

		if (allowListeners) {
			var ct = getInterfaceName().asComplexType();
			var listeneners = {
				name: "_listeners",
				doc: null,
				meta: [],
				access: [APrivate],
				kind: FVar("Array".asComplexType( [TPType(ct)]), ENew("Array".asTypePath( [TPType(ct)]), []).at()),
				pos: Context.currentPos()
			};

			fields.push(listeneners);

			fields.push(makeMemberFunction("addListener", (macro _listeners.push(l)).func( ["l".toArg( ct)]), []));
		}

		if (signals) {
			for (n in model.nodes) {
				var name = 'sig${n.name}';

				var sigMember = {
					name: name,
					doc: null,
					meta: [],
					access: [APublic],
					kind: FVar(macro :hsig.Signal3<ai.sm.State, ai.sm.Transition, Bool>, macro new hsig.Signal3<ai.sm.State, ai.sm.Transition, Bool>()),
					pos: Context.currentPos()
				};

				fields.push(sigMember);
			}
		}


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

	static function buildFireFunction( graph:NodeGraph) {
		var stateCases = new Array<Case>();

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
				s.walkOutgoingNonChildren((trigger) -> {
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
					blockArray.push(exprCall("onExit" + currentNode.name, [exprID("trigger")]));
					//trace('\t\tBuilding on exit ${currentNode.name} by ${trigger.name} ');

					var leafState = getInitialLeaf(targetState);
					var leafStateName = leafState.name;

					var commonRoot = s.firstCommonAncestor(leafState);
					var parent = currentNode.parent; //s.parent;

					while (parent != commonRoot && parent != null) {
						var pName = parent.name;
						blockArray.push(exprCall("onExit" + pName, [exprID("trigger")]));
						//trace('\t\t\tAdding exit ${pName}');

						exited.push(pName);
						parent = parent.parent;
					}

					// Does the arc fire now?
					blockArray.push(exprCall("onTraverse", [exprID("trigger")]));

					var walkList = new Array<NodeGraphNode>();

					parent = leafState.parent;
					while (parent != commonRoot && parent != null) {
						walkList.push(parent);
						parent = parent.parent;
					}

					walkList.reverse();

					for (targetAncestor in walkList) {
						for (exit in exited) {
							blockArray.push(exprCall("onEnterFrom" + targetAncestor.name, [exprID("S_" + exit)]));
						}
						blockArray.push(exprCall("onEnterBy" + targetAncestor.name, [exprID("T_" + trigger.name)]));
					}
					// TBD Support multiple machines
					blockArray.push(exprID("_state0").assign( exprID("S_" + leafStateName)));

					for (exit in exited) {
						blockArray.push(exprCall("onEnterFrom" + leafStateName, [exprID("S_" + exit)]));
					}

					blockArray.push(exprCall("onEnterBy" + leafStateName, [exprID("T_" + trigger.name)]));
					var tc:Case = {values: [EConst(CIdent("T_" + trigger.name)).at()], expr: blockArray.toBlock()};
					triggerCases.push(tc);
				});
				s = parent;
			}

			var triggerSwitch = ESwitch(EConst(CIdent("trigger")).at(), triggerCases, EBlock([]).at()).at();

			var stateCasec:Case = {values: [EConst(CIdent("S_" + currentNode.name)).at()], expr: triggerSwitch};
			stateCases.push(stateCasec);
		}

		var funBlock = new Array<Expr>();

		//		funBlock.push( macro if (_triggerQueue == null) trace("_triggerQueue is null???"));
		funBlock.push(macro _triggerQueue.push(trigger));
		funBlock.push(macro if (_inTransition)
			return);
		funBlock.push(macro _inTransition = true);

		var swBlockArray = new Array<Expr>();

		var defaultStates = [getDefaultState(graph)];

		for (i in 0...defaultStates.length) {
			var sw = ESwitch(EConst(CIdent("_state" + i)).at(), stateCases, EThrow(EConst(CString("State not found")).at()).at()).at();
			swBlockArray.push(sw);
		}

		var swBlock = EBlock(swBlockArray).at();

		funBlock.push(macro while (_triggerQueue.length > 0) {
			trigger = _triggerQueue.pop();
			$swBlock;
		});

		funBlock.push(macro _inTransition = false);

		var arg:FunctionArg = {name: "trigger", type: macro :Int};
		var fun:Function = {args: [arg], expr: EBlock(funBlock).at()};

		var fireFunc = {
			name: "fire",
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

		blockArray.push(exprIf(exprEq(exprID("_state0"), exprID("state")), macro return true));

		var cases = new Array<Case>();

		for (s in model.nodes) {
			if (!isValidLeafNode(s))
				continue;

			var subcases = new Array<Case>();
			var parent = s.parent;

			while (parent != null) {
				var c:Case = {values: [exprID("S_" + parent.name)], expr: macro return true};
				subcases.push(c);

				parent = parent.parent;
			}

			var caseExpr = subcases.length > 0 ? ESwitch(exprID("state"), subcases, EBlock([]).at()).at() : macro return false;

			var theCase:Case = {values: [EConst(CIdent("S_" + s.name)).at()], expr: caseExpr};
			cases.push(theCase);
		}

		var throwExpr = macro throw 'State not found ${_state0}';
		var sw = ESwitch(EConst(CIdent("_state0")).at(), cases, throwExpr).at();

		blockArray.push(sw);
		blockArray.push(macro return false);

		return {
			name: "isIn",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FFun({args: [{name: "state", type: macro :Int}], expr: EBlock(blockArray).at()}),
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
	static function exprCallField(f:Field, a:Expr, b:Expr = null, allowSingle:Bool = true):Expr {
		switch (f.kind) {
			case FFun(fun):
				if (fun.args.length == 0) {
					return EConst(CIdent(f.name)).at().call( []);
				}
				if (fun.args.length == 1) {
					if (allowSingle) {
						var ct:ComplexType = fun.args[0].type;
						if (ComplexTypeTools.toString(fun.args[0].type) == "ai.sm.State") {
							return EConst(CIdent(f.name)).at().call( [a]);
						} else if (ComplexTypeTools.toString(fun.args[0].type) == "ai.sm.Transition") {
							return EConst(CIdent(f.name)).at().call( [b]);
						}
					}

					throw 'Unsupported parameter pattern on ${f.name}';
				}
				if (fun.args.length == 2 && b != null) {
					return EConst(CIdent(f.name)).at().call( [a, b]);
				}

				throw 'Unsupported parameter pattern on ${f.name}';
			default:
				throw "Not a function";
		}

		return null;
	}

	static public function buildEventFunctions( actions:ActionMaps, model:NodeGraph, allowListeners:Bool, signals:Bool,
			ticking:Bool) {
		var fields = [];
		var caseArray = new Array<Case>();
		var transitionExpr = exprID("transition");
		var transitionNames = model.gatherOutgoingRelationNames();
		for (t in transitionNames) {
			var transitionNameExpr = exprID("T_" + t);

			var handlerArray = new Array<Expr>();
			if (actions.traverse.exists(t)) {
				for (a in actions.traverse[t])
					handlerArray.push(exprCallField(a, transitionNameExpr, transitionExpr));
				caseArray.push({values: [transitionNameExpr], expr: EBlock(handlerArray).at()});
			}
		}

		fields.push(makeMemberFunction("onTraverse",
			ESwitch(transitionExpr, caseArray, null).at().func( ["transition".toArg( macro :Int)], null, null, false), [AInline, AFinal]));

		for (n in model.nodes) {
			var s = n.name;
			var stateNameExpr = exprID("S_" + s);
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

			if (allowListeners) {
				var index = macro _listeners[i];
				var call = EField(index, "onEnterBy" + s).at();
				handlerArray.push(exprFor(macro i, macro _listeners.length, macro $call($stateNameExpr, trigger)));
			}

			for (ge in actions.globalEntry) {
				handlerArray.push(exprCallField(ge, stateNameExpr, triggerExpr));
			}

			if (signals) {
				var sigName = "sig" + s;
				var x = macro $i{sigName}.dispatch($i{"S_" + s}, trigger, true);
				handlerArray.push(x);
			}

			if (ticking) {
				var whiles = actions.whiles.get(s);
				if (whiles != null) {
					var whileArray = new Array<Expr>();
					for (w in whiles) {
						var mm = w.meta.toMap();
						if (mm.exists(":after")) {
							var tname = "__timer_" + w.name;
							handlerArray.push(macro $i{tname} = __state_now);
						}
					}
				}
			}

			fields.push(makeMemberFunction("onEnterBy" + s, handlerArray.toBlock().func( ["trigger".toArg( macro :Int)]),
				[AInline, AFinal]));

			handlerArray.resize(0);
			if (actions.exit.exists(s))
				for (a in actions.exit[s])
					handlerArray.push(exprCallField(a, stateNameExpr, triggerExpr));
			if (allowListeners) {
				var call = EField(macro _listeners[i], "onExit" + s).at();
				handlerArray.push(exprFor(macro i, macro _listeners.length, macro $call($stateNameExpr, trigger)));
			}
			if (signals) {
				var sigName = "sig" + s;
				var x = macro $i{sigName}.dispatch($i{"S_" + s}, trigger, false);
				handlerArray.push(x);
			}
			fields.push(makeMemberFunction("onExit" + s, handlerArray.toBlock().func( ["trigger".toArg( macro :Int)]),
				[AInline, AFinal]));
			handlerArray.resize(0);
			if (actions.entryFrom.exists(s))
				for (a in actions.entryFrom[s])
					handlerArray.push(isEmpty(a.transition) ? exprCallField(a.field, stateNameExpr, stateExpr,
						false) : exprIf(exprEq(exprID("state"), exprID("S_" + a.transition)), exprCallField(a.field, stateNameExpr, stateExpr, false)));
			if (allowListeners) {
				var call = EField(macro _listeners[i], "onEnterFrom" + s).at();
				handlerArray.push(exprFor(macro i, macro _listeners.length, macro $call($stateNameExpr, state)));
			}

			fields.push(makeMemberFunction("onEnterFrom" + s, handlerArray.toBlock().func(["state".toArg( macro :Int)]),
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

	static var _printer = new Printer();

	static function getInterfaceName() {
		return "I" + Context.getLocalClass().get().name + "Listener";
	}

	static public function buildInterface(path:String, machine:String) {
		var graph = getGraph(path, machine);

		var fields = new Array<Field>();

		for (n in graph.nodes) {
			var x:Function = {args: ["trigger".toArg( macro :Int)]};

			var s = n.name;
			fields.push(makeMemberFunction("onEnterBy" + s,
				{ret: macro :Void, args: ["state".toArg( macro :Int), "trigger".toArg( macro :Int)]}, []));
			fields.push(makeMemberFunction("onExit" + s,
				{ret: macro :Void, args: ["state".toArg( macro :Int), "trigger".toArg( macro :Int)]}, []));
			fields.push(makeMemberFunction("onEnterFrom" + s,
				{ret: macro :Void, args: ["from".toArg( macro :Int), "to".toArg( macro :Int)]}, []));
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

	static function initialChild(node:NodeGraphNode) {
		return node.getChildren().find((x) -> x.properties.exists('initial'));
	}

	static function getInitialLeaf(node:NodeGraphNode) {
		if (node.hasChildren()) {
			var x = node.getChildren().find((x) -> x.properties.exists('initial'));
			if (x != null)
				return getInitialLeaf(x);
			throw('No initial state for node ${node.name}');
		}
		return node;
	}

	static function getNameEnumStateName(node:NodeGraphNode) {
		return "S_" + node.name;
	}

	static function getDefaultState(graph:NodeGraph) {
		var defaultState = graph.nodes.find((x) -> x.properties.exists("default") || x.properties.exists("root") && x.parent == null);
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
		return getNameEnumStateName(getDefaultState(graph));
	}

	/*
	static function buildConstructor( model:NodeGraph) {
		var con = cb.getConstructor();

		Context.fatalError("Automatic constructor generation is unsupported atm", Context.currentPos());

		con.init("_state0", Context.currentPos(), Value(exprID(getDefaultStateName(model))));
		con.publish();
	}*/

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
				var stateNameExpr = exprID(getNameEnumStateName(curState));
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

	static function buildSignalFunctions( model:NodeGraph) {}

	static function buildTickFunction( model:NodeGraph, actions:ActionMaps, signals:Bool) {
		var whiles = actions.whiles;
		var caseList = new Array<Case>();

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
						var calle = exprID(f.name).call([exprID("delta"), exprID("time")]);

						var ae = mm.get(":after");

						if (ae != null && ae.length > 0) {
							var cond = mm.get(":after").flatten()[0];
							var timerID = exprID( "__timer_" + f.name);
							var test = macro (__state_now - $timerID > $cond);
							return macro if ($test) $calle;
						} else {
							return calle;
						}
					});

					for (fc in fcalls) {
						blockList.push(fc);
					}
				}
				cur = cur.parent;
			}

			if (blockList.length > 0) {
				var ecase:Case = {values: [exprID("S_" + sn.name)], expr: macro $b{blockList}};
				caseList.push(ecase);
			}
		}

		var swblock = EBlock([
			macro __state_now = time,
			ESwitch(exprID("_state0"), caseList, macro {}).at()
		]).at();
		var ff = swblock.func(["delta".toArg(macro :Float), "time".toArg(macro :Float)], false);
		return makeMemberFunction("__state_tick", ff, [AFinal]);
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

	macro static public function build(path:String, machine:String, makeInterface:Bool, constructor:Bool):Array<Field> {
		// trace("Building state machine " + Context.getLocalClass().get().name);
		
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

		var cm = Context.getLocalClass().get().meta.get().toMap();
		var signals = cm.exists(":sm_signals");
		var debug = cm.exists(":sm_debug");
		var ticking = cm.exists(":sm_tick");


		var constantFields : Array<Field> = buildConstantFields( model);
		var actions = getActions();

		var timers = [];

		var varFields : Array<Field> = buildVars( model, actions, makeInterface, signals, ticking, timers);
		var eventFunctions  : Array<Field> = buildEventFunctions( actions, model, makeInterface, signals, ticking);

		var fields = Context.getBuildFields().concat(constantFields).concat(varFields).concat(eventFunctions);

		fields.push(buildFireFunction( model));
		fields.push(buildIsInFunction( model));
		fields.push(buildFireStrFunction( model));
		if (ticking) {
			fields.push(buildTickFunction( model, actions, signals));
		}
		if (makeInterface) {
			buildInterface(path, machine);
		}

		if (constructor) {
// /			buildConstructor( model);
		} else {
			fields.push(buildInitFunction( actions, model, ticking, timers));
		}

		fields.push(buildResetFunction( actions, model, ticking, timers));

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
