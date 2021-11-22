package sm.macro;

import tink.macro.Ops.Binary;
import tink.macro.Exprs.VarDecl;
import haxe.macro.MacroStringTools;
import tink.macro.Ops.Unary;
import tink.macro.ConstParam;
#if macro
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
	}

	static function buildOverlayInterface(model:StateMachineModel) {}

	static function exprConstString(s:String) {
		return Exprs.at(EConst(CString(s)));
	}

	static function exprID(s:String) {
		return Exprs.at(EConst(CIdent(s)));
	}

	static function exprCall(method:String, ?params:Array<Expr>) {
		return Exprs.call(Exprs.at(EConst(CIdent(method))), params);
	}

	static function buildFireFunction(cb:tink.macro.ClassBuilder, model:StateMachineModel) {
		var stateCases = new Array<Case>();

		trace("Building fire");

		for (s in model.stateShapes) {
			trace('Trying ${s.nodeName}');
			if (isGroupNode(s) || isGroupProxy(s))
				continue;
			var content = getStateShapeName(s);
			trace('Named ${content}');
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
				trace('Walking ${getStateShapeName(s)} [${getStateShapeName(parent)}] ');
				model.graph.walkOutgoingConnections(s, x -> trace('Missing transition information on ${x}'), (trigger, targetState) -> {
					var sourceStateName = getStateShapeName(s);
					var targetStateName = getStateShapeName(targetState);
					trace('Walk: ${sourceStateName} by ${trigger} -> ${targetStateName}');
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

					trace('Parent: ${getStateShapeName(parent)}');
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

		blockArray.push(exprIf(exprEq(exprID("_state0"), exprID("state")), macro true));

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
			cb.addMember(makeMemberFunction("onEnterBy" + s, Functions.func(Exprs.toBlock([]), [Functions.toArg("trigger", macro:Int)])));
			cb.addMember(makeMemberFunction("onExit" + s, Functions.func(Exprs.toBlock([]), [Functions.toArg("trigger", macro:Int)])));
			cb.addMember(makeMemberFunction("onEnterFrom" + s, Functions.func(Exprs.toBlock([]), [Functions.toArg("state", macro:Int)])));

			/*
					@this.WriteLine( "[MethodImpl(MethodImplOptions.AggressiveInlining)]");
					@this.WriteLine( "void OnEnter"+ s + "( ETrigger trigger) {");
					@this.PushIndent("\t");
					@this.WriteLine( "for (var i = 0; i < _listeners.Count; i++) {");
					@this.PushIndent("\t");
					@this.WriteLine( "_listeners[i].OnEnter"+ s +" ( trigger);");
					@this.PopIndent();
					@this.WriteLine("}");
					@this.PopIndent();
					@this.PushIndent("\t");
					@this.PopIndent();
					@this.WriteLine("}");
					@this.WriteLine( "[MethodImpl(MethodImplOptions.AggressiveInlining)]");
					@this.WriteLine( "void OnEnter"+ s + "( EState state){");
					@this.PushIndent("\t");
					@this.WriteLine( "for (var i = 0; i < _listeners.Count; i++) {");
					@this.PushIndent("\t");
					@this.WriteLine( "_listeners[i].OnEnter"+ s +" ( state);");
					@this.PopIndent();
					@this.WriteLine("}");
					@this.PopIndent();
					@this.WriteLine("}");
					@this.WriteLine( "[MethodImpl(MethodImplOptions.AggressiveInlining)]");
					@this.WriteLine( "void OnExit"+ s + "( ETrigger trigger) {");
					@this.PushIndent("\t");
					@this.WriteLine( "for (var i = 0; i < _listeners.Count; i++) {");
					@this.PushIndent("\t");
					@this.WriteLine( "_listeners[i].OnExit"+ s +" ( trigger);");
					@this.PopIndent();
					@this.WriteLine("}");
					@this.PopIndent();
					@this.WriteLine("}");
				}
			 */
		}
	}
 
    static var _machines = new Map<String, StateMachineModel>();
    
    static function getMachine( path:String, machine:String ) : StateMachineModel {
        var key = path + "_" + machine;
        var m = _machines.get(key);

        if (m == null) {
            var smArray = Visio.read(path);
            for(sm in smArray) {
                var key = path + "_" + sm.name;
                _machines[key] = sm;
            }
        }
        m = _machines.get(key);
        if (m==null) {
            throw 'No machine ${machine} found in ${path}';
        }
        return m;
    }
    static var _printer = new Printer();

    static public function buildInterface( path:String, machine:String) {
        var model = getMachine( path, machine );

        var cb = new tink.macro.ClassBuilder();

        var moduleName = Context.getLocalModule();

        Context.defineType({pack:Context.getLocalClass().get().pack,name:"I" + Context.getLocalClass().get().name + "Listener", pos:Context.currentPos(), kind:TDClass( null, null, true ), fields : [] });

        /*
 @this.WriteLine("public interface IOverlay : IStateMachineOverlay {");
        @this.PushIndent("\t");
        foreach (var s in stateMachine.StateNames) {
            @this.WriteLine( "void OnEnter"+ s + "( ETrigger trigger);");
            @this.WriteLine( "void OnEnter"+ s + "( EState state);");
            @this.WriteLine( "void OnExit"+ s + "( ETrigger trigger);");
        }

        @this.PopIndent();
        @this.WriteLine("}");
        
        @this.WriteLine( "List<IOverlay> _listeners = new List<IOverlay>();");
        @this.WriteLine( "public override void Listen(IStateMachineOverlay listen){");
        @this.PushIndent("\t");
        @this.WriteLine( "var l = listen as IOverlay;");
        @this.WriteLine( "switch(_state) {");
        @this.PushIndent("\t");
        foreach (var s in stateMachine.StateNames) {
            @this.WriteLine("case EState." + s +": l.OnEnter" + s + "( ETrigger.NONE); break;");
        }

        @this.PopIndent();
        @this.WriteLine("}");
        @this.WriteLine( "_listeners.Add(l);");
        @this.PopIndent();
        @this.WriteLine("}");
        foreach (var s in stateMachine.StateNames) {
            
            @this.WriteLine( "[MethodImpl(MethodImplOptions.AggressiveInlining)]");
            @this.WriteLine( "void OnEnter"+ s + "( ETrigger trigger) {");
            @this.PushIndent("\t");
            @this.WriteLine( "for (var i = 0; i < _listeners.Count; i++) {");
            @this.PushIndent("\t");
            @this.WriteLine( "_listeners[i].OnEnter"+ s +" ( trigger);");
            @this.PopIndent();
            @this.WriteLine("}");
            @this.PopIndent();
            @this.PushIndent("\t");
            @this.PopIndent();
            @this.WriteLine("}");
            @this.WriteLine( "[MethodImpl(MethodImplOptions.AggressiveInlining)]");
            @this.WriteLine( "void OnEnter"+ s + "( EState state){");
            @this.PushIndent("\t");
            @this.WriteLine( "for (var i = 0; i < _listeners.Count; i++) {");
            @this.PushIndent("\t");
            @this.WriteLine( "_listeners[i].OnEnter"+ s +" ( state);");
            @this.PopIndent();
            @this.WriteLine("}");
            @this.PopIndent();
            @this.WriteLine("}");
            @this.WriteLine( "[MethodImpl(MethodImplOptions.AggressiveInlining)]");
            @this.WriteLine( "void OnExit"+ s + "( ETrigger trigger) {");
            @this.PushIndent("\t");
            @this.WriteLine( "for (var i = 0; i < _listeners.Count; i++) {");
            @this.PushIndent("\t");
            @this.WriteLine( "_listeners[i].OnExit"+ s +" ( trigger);");
            @this.PopIndent();
            @this.WriteLine("}");
            @this.PopIndent();
            @this.WriteLine("}");
        }
        */
        var xx = cb.export(false);

		for (x in xx) {
			trace(_printer.printField(x));
		}
		return xx;
    }

	macro static public function build(path:String, machine:String, makeInterface : Bool):Array<Field> {
		var model = getMachine( path, machine );

		var cb = new tink.macro.ClassBuilder();

		buildConstants(cb, model);
		buildVars(cb, model);

		buildOverlayInterface(model);
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
