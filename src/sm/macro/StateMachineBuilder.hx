package sm.macro;

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

    static function makeMemberFunction(n:String, f:Function) : Field {
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
        for(ds in model.defaultStates) {
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

	/*
		public static Dictionary<string, StateMachineGraph> WriteStateMachineClass(TextTransformation @this, string path, bool reactive = false) {
			var stateMachines = new Dictionary<string, StateMachineGraph>();
			var machinesDoc = Thor.Tools.CodeGeneration.XML.StringToXMLDocument(File.ReadAllText(path), e => { });

			var pages = Import.GetPages(machinesDoc.DocumentElement);

			foreach (var page in pages) {
				var stateMachine = new StateMachineGraph(page);

				stateMachines[stateMachine.Name.ToUpper()] = stateMachine;

				var className = stateMachine.ClassName;

				if (reactive) {
					@this.WriteLine("public  class " + className + "  : AObservableStateMachine<" + className + ".EState, " + className + ".ETrigger> {");
				}
				else {
					@this.WriteLine("public  class " + className + "  : AStateMachine<" + className + ".EState, " + className + ".ETrigger> {");
				}
				@this.PushIndent("\t");
				@this.WriteLine(" public " + className + "() : base(EState." + stateMachine.DefaultState + ") {");
				
				@this.WriteLine("}");
				
				StateMachines.WriteEnumDefinition(@this, stateMachine.StateNames, stateMachine.TransitionNames);

				WriteOverlayInterface(@this, stateMachine);
				
				
				if (reactive) {
					foreach (var s in stateMachine.StateNames) {
						@this.WriteLine("\t\tpublic System.IObservable<EState> Enter" + s +
										" => EnterState.Observe.Where( x => x  == EState." + s + ");");
						@this.WriteLine("\t\tpublic System.IObservable<(EState,ETrigger)> Enter" + s +
										"By => EnterStateBy.Observe.Where( x => x.Item1  == EState." + s + ");");
						@this.WriteLine("\t\tpublic System.IObservable<EState> Exit" + s +
										" => ExitState.Observe.Where( x => x  == EState." + s + ");");
						@this.WriteLine("\t\tpublic System.IObservable<(EState,ETrigger)> Exit" + s +
										"By => EnterStateBy.Observe.Where( x => x.Item1  == EState." + s + ");");
					}
				}

				WriteFire(@this, stateMachine);
				WriteIsInFunction(@this, stateMachine.StateShapes);
				WriteFireStrFunction(@this, stateMachine);
				@this.PopIndent();
				@this.WriteLine("}");
			}

		   

			return stateMachines;
		}
	 */
	static function buildOverlayInterface(model:StateMachineModel) {}

	static function exprConstString(s:String) {
		return Exprs.at(EConst(CString(s)));
	}

    static function exprID(s:String) {
		return Exprs.at(EConst(CIdent(s)));
	}

    static function exprCall(method:String, ?params : Array<Expr>) {
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

                    trace('Parent: ${ getStateShapeName(parent)}');
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

                    for ( targetAncestor in walkList) {
                        for ( exit in exited) {
                            blockArray.push(exprCall("onEnterFrom" + getStateShapeName(targetAncestor), [exprID("S_" + exit)]));
                        }
                        blockArray.push(exprCall("onEnterBy" + getStateShapeName(targetAncestor), [exprID("T_" + trigger)]));
                    }
                    // TBD Support multiple machines
                    blockArray.push(Exprs.assign(exprID("_state0"), exprID("S_" + leafStateName)));

                    for ( exit in exited) {
                        blockArray.push(exprCall("onEnterFrom" + leafStateName, [exprID("S_" + exit)]));
                    }

                    blockArray.push(exprCall("onEnterBy" + leafStateName, [exprID("T_" + trigger)]));
                    var tc:Case = {values: [Exprs.at(EConst(CIdent("T_" + trigger)))], expr: Exprs.toBlock(blockArray)};
                    triggerCases.push(tc);
				
				});
				s = parent;
			}

            var triggerSwitch =  Exprs.at(ESwitch(Exprs.at(EConst(CIdent("trigger"))), triggerCases, null));

            var stateCasec:Case = {values: [Exprs.at(EConst(CIdent("S_" + content)))], expr: triggerSwitch};
			stateCases.push(stateCasec);
		}

        var switches = new Array<Expr>();

        for( i in 0...model.defaultStates.length) {
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

		//var pp = new Printer();
		//trace(pp.printField(fireFunc));


		/*

			if (stateMachine.ReEntrant) {
				@this.WriteLine("bool _inTransition = false;");
				@this.WriteLine("Queue<ETrigger> _triggerQueue = new ();");
			}

			@this.WriteLine("public void Fire( ETrigger trigger) {"); 
			@this.PushIndent("\t"); 
			if (stateMachine.ReEntrant) {
				@this.WriteLine("if (_inTransition) {");
				@this.PushIndent("\t");
				@this.WriteLine("_triggerQueue.Enqueue(trigger);");
				@this.WriteLine("return;");
				@this.PopIndent();
				@this.WriteLine("}");

				@this.WriteLine("_inTransition = true;");
			}
			@this.WriteLine(" switch(_state) {");
			foreach (var s in stateMachine.StateShapes) {
				var element = s;
				if (element.IsGroupNode() || element.IsGroupProxy()) continue;
				var content = element.GetStateShapeName();
				if (content == null) continue;

				@this.WriteLine("\t\t\tcase EState." + content + ":");
				@this.WriteLine("\t\t\t\tswitch(trigger) {");


				HashSet<string> triggers = new HashSet<string>();


				var currentElement = element;

				while (element != null && (element.IsStateShape() || element.IsGroupNode())) {
					var parent = element.GetParentGroup();
					if (element.IsGroupProxy()) {
						element = parent;
						parent = element.GetParentGroup();
					}


					stateMachine.Graph.WalkOutgoingConnections(element,
						x => { @this.WriteLine("#Error missing transition information on " + x); },
						(trigger, state) => {

							if (triggers.Contains(trigger)) {
								@this.WriteLine("Overlapping triggers " + trigger);
								throw new FormatException("Overlapping triggers " + trigger);
							}
							else {
								@this.WriteLine("\t\t\t\tcase ETrigger." + trigger + ": {");

								List<string> exited = new List<string>();
								
								@this.WriteLine("\t\t\t\t\tOnExit" + currentElement.GetStateShapeName() + "( ETrigger." +
												trigger + ");");
								exited.Add( currentElement.GetStateShapeName() );
								// Need to walk up the hierarchy
								//WriteLine("\t\t\t\t\tExitStateBy.OnNext( (EState." + currentElement.GetStateShapeName() +", trigger));");
								//WriteLine("\t\t\t\t\tExitState.OnNext( EState." + currentElement.GetStateShapeName() +"  );");

								var leafState = state.GetInitialLeaf();
								var leafStateName = leafState.GetStateShapeName();

								var commonRoot = currentElement.FirstCommonAncestor(leafState);

								var parent = currentElement.GetParentGroup();
								while (parent != commonRoot && parent != null) {
									@this.WriteLine("\t\t\t\t\tOnExit" + parent.GetStateShapeName() +
													"( ETrigger." +
													trigger + ");");
									exited.Add(parent.GetStateShapeName());
			//                                    WriteLine("\t\t\t\t\tExitStateBy.OnNext( (EState." + parent.GetStateShapeName() +", trigger));");
			//                                  WriteLine("\t\t\t\t\tExitState.OnNext( EState." + parent.GetStateShapeName() + ");");
									parent = parent.GetParentGroup();
								}

								var walkList = new List<IElement>();

								parent = leafState.GetParentGroup();
								while (parent != commonRoot && parent != null) {
									walkList.Add(parent);
									parent = parent.GetParentGroup();
								}

								foreach (var targetAncestor in (walkList as IEnumerable<IElement>).Reverse()) {
									foreach (var exit in exited) {
										@this.WriteLine("\t\t\t\t\tOnEnter" + targetAncestor.GetStateShapeName() + " ( EState." + exit + ");");
									}
									@this.WriteLine("\t\t\t\t\tOnEnter" + targetAncestor.GetStateShapeName() + " ( ETrigger." + trigger + ");");
			//                                    WriteLine("\t\t\t\t\tEnterStateBy.OnNext( (EState." +targetAncestor.GetStateShapeName() + ", trigger));");
			//                                    WriteLine("\t\t\t\t\tEnterState.OnNext( EState." + targetAncestor.GetStateShapeName() +    ");");
								}

								@this.WriteLine("\t\t\t\t\t_state = EState." + leafStateName + "; ");
								foreach (var exit in exited) {
									@this.WriteLine("\t\t\t\t\tOnEnter" + leafStateName + "( EState." + exit + ");");
								}

								@this.WriteLine("\t\t\t\t\tOnEnter" + leafStateName + "( ETrigger." + trigger + ");");

								//WriteLine("\t\t\t\t\tEnterStateBy.OnNext( (EState." + leafStateName + ", trigger));");
								//WriteLine("\t\t\t\t\tEnterState.OnNext( EState." + leafStateName + ");");

								@this.WriteLine("\t\t\t\tbreak;}");
							}

						});
					element = parent;
				}


				@this.WriteLine("\t\t\t\t}");
				@this.WriteLine("\t\t\t\tbreak;");

			}

			@this.PopIndent();
			@this.WriteLine("}");
			if (stateMachine.ReEntrant) {
				@this.WriteLine("_inTransition = false;");
				@this.WriteLine("if (_triggerQueue.Count > 0){");
				@this.PushIndent("\t");
				@this.WriteLine("Fire(_triggerQueue.Dequeue());");
				@this.PopIndent();
				@this.WriteLine("}");
			}

			@this.PopIndent();
			@this.WriteLine("}");
		 */

         cb.addMember(fireFunc);
	}

	static function buildIsInFunction(cb:tink.macro.ClassBuilder, model:StateMachineModel) {}

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
        for ( s in model.stateNames) {
            
            cb.addMember(makeMemberFunction( "onEnterBy" + s, Functions.func( Exprs.toBlock([]), [Functions.toArg("trigger", macro : Int)] ) ));
            cb.addMember(makeMemberFunction( "onExit" + s, Functions.func( Exprs.toBlock([]), [Functions.toArg("trigger", macro : Int)] ) ));
            cb.addMember(makeMemberFunction( "onEnterFrom" + s, Functions.func( Exprs.toBlock([]), [Functions.toArg("state", macro : Int)] ) ));

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
	macro static public function build(path:String, machine:String):Array<Field> {
		var smArray = Visio.read(path);

		var model:StateMachineModel = null;
		for (sm in smArray) {
			if (sm.name == machine) {
				model = sm;
				break;
			}
		}
		if (model == null) {
			throw "No machine found";
		}
		var cb = new tink.macro.ClassBuilder();

		buildConstants(cb, model);
        buildVars(cb, model);

		buildOverlayInterface(model);
        buildEventFunctions(cb,model);
		buildFireFunction(cb, model);
		buildIsInFunction(cb, model);
		buildFireStrFunction(cb, model);

		var xx = cb.export(false);

        var pp = new Printer();
		

        for( x in xx) {
            trace(pp.printField(x));
        }
        return xx;
	}
}
#end
