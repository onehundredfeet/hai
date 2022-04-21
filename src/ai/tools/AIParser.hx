package ai.tools;

import ai.tools.Lexer;
import ai.tools.AST;

class AIParser extends Lexer {
	var types:Map<String, ExpressionType>;

	public function new() {
		super();
		types = new Map<String, ExpressionType>();

		types.set("Float", ETFloat);
		types.set("Bool", ETBool);
		types.set("Int", ETInt);
	}

	function parseType():ExpressionType {
		var ts = ident();

		var x = types[ts];
		if (x != null) {
			return x;
		}
		unexpected(TId(ts));
		return null;
	}

	public function parseFile(fileName:String, input:haxe.io.Input):Array<Declaration> {
		this.fileName = fileName;
		pos = 0;
		line = 1;
		char = -1;
		tokens = [];
		this.input = input;
		var declarations = new Array<Declaration>();

		trace('Starting parsing...${fileName}');

		var alignment = 0;

		while (true) {
			var tk = next(false);
			// trace ('token: ${tokenString(tk)}');
			if (tk == TEof)
				break;
			if (tk == TNewLine) {
				alignment = 0;
				continue;
			}
			if (tk == TTab) {
				alignment += 4;
				continue;
			}
			if (tk == TSpace) {
				alignment += 1;
				continue;
			}
			if (tk == THash) {
				discardLine();
				alignment = 0;
				continue;
			}
			// trace('Parsing ${tk}');

			if (alignment == 0) {
				returnToken(tk);
				declarations.push(parseDeclLine(0, declarations));
			} else {
				error('Declarations should not have whitespace in front of them ${tk}');
			}
		}
		return declarations;
	}

	function parseBooleanExpression():BooleanExpression {
		var top:BooleanExpression = null;

		var tk = nextUnless(TNewLine);

		if (tk == TNewLine) {
			returnToken(tk);
			return BELiteral(true);
		}

		while (tk != TNewLine) {
			switch (tk) {
				case TBrOpen:
				case TBrClose:
				case TId(ident):
					if (ident == "true")
						top = BELiteral(true);
					else if (ident == "false")
						top = BELiteral(false);
					else
						top = BEIdent(ident);
				case TOp("!"):
					top = BEUnaryOp("!", parseBooleanExpression());
				case TOp(op):
					if (top == null)
						error("Binary operator requires left hand operand");
					top = BEBinaryOp(op, top, parseBooleanExpression());
				default:
					break;
			}

			//            trace('Top is now ${top}');

			tk = nextUnless(TNewLine);
		}

		returnToken(tk);

		// trace('Boolean expression ${top}');
		return top;
	}

	/*
		function parseCallArgument() : Argument {
			var x = ident();
			ensure(TColon);
			var y = ident();
			//trace('Argument found ${x} : ${y}');
			return {name:x, value:y};
		}


		function parseParameterDecl() : Parameter {
			var x = ident();
			ensure(TColon);
			var y = ident();
			//trace('Parameter found ${x} : ${y}');
			return {name:x, type:y};
		}

		function parseParameterList() : Array<Parameter> {
			var list = [];

			var n = next();

			while (n != TPClose) {
				returnToken(n);
				list.push(parseParameterDecl());
				n = next();
				if (n == TComma) n = next();
			}

			return list;
		}
	 */
	function parseSubtask(name:String, alignment):SubTask {
		/*
			if (maybe(TPOpen)) {
			//            trace("Subtask has arguments");
				var n = next();
				var params = [];

				while (n != TPClose) {
					returnToken(n);
					params.push(parseCallArgument());
					n = next();
					if (n == TComma) n = next();
				}

				ensure(TNewLine);
				return {name:name, paramters: params};
			}
		 */

		ensure(TNewLine);
		return {name: name, paramters: []};
	}

	function parseMethod(name:String, alignment):Method {
		var conditions = maybe(TColon) ? parseBooleanExpression() : BELiteral(true);

		ensure(TNewLine);

		var subAlign = 0;
		var subTasks = new Array<SubTask>();

		while ((subAlign = peekAlignment()) > alignment) {
			switch (next()) {
				case TId(s):
					subTasks.push(parseSubtask(s, subAlign));
				case var x:
					trace('Something else ${x}');
			}
		}
		return {name: name, condition: conditions, subtasks: subTasks};
	}

	 function isUnaryOp(op:String) {
		return switch (op) {
			case "!", "-": true;
			default: false;
		}
	}
	function isBinaryOp(op:String) {
		return switch (op) {
			case "%": true;
			case "*", "/": true;
			case "+", "-": true;
			case ">", "<", ">=", "<=", "==": true;
			case "&&": true;
			case "||":true;
			default: false;
		}
	}
	function exprUnaryPrecedence(op:String) {
		return switch (op) {
			case "!", "-": 7;
			default: 0;
		}
	}
	function exprBinaryPrecedence(op:String) {
		return switch (op) {
			case "%": 6;
			case "*", "/": 5;
			case "+", "-": 4;
			case ">", "<", ">=", "<=", "==": 3;
			case "&&": 2;
			case "||":1;
			default: 0;
		}
	}


	/*
		

		P is
		if next is a unary operator
			 const op := unary(next)
			 consume
			 q := prec( op )
			 const t := Exp( q )
			 return mkNode( op, t )
		else if next = "("
			 consume
			 const t := Exp( 0 )
			 expect ")"
			 return t
		else if next is a v
			 const t := mkLeaf( next )
			 consume
			 return t
		else
			 error
	 */

	function numExprP():NumericExpression {
		var x = nextUnless(TNewLine);

		switch (x) {
			case TOp(op):
				if (isUnaryOp(op)) {
					// unary
					var q = exprUnaryPrecedence(op);
					var t = numExprExp(0);
					return NEUnaryOp(op, t);
				}
				unexpected(x);
			case TPOpen:
				var t = numExprExp(0);
				ensure(TPClose);
				return t;
			case TId(s):
				return NEIdent(s);
			case TNumber(value):
				return NELiteral(value);
			default:
				returnToken(x);
		}
		return null;
	}

	/*
		Exp( p ) is
		var t : Tree
		t := P
		while next is a binary operator and prec(binary(next)) >= p
		   const op := binary(next)
		   consume
		   const q := case associativity(op)
					  of Right: prec( op )
						 Left:  1+prec( op )
		   const t1 := Exp( q )
		   t := mkNode( op, t, t1)
		return t
	 */
	function numExprExp(p:Int):NumericExpression {
		var t = numExprP();

		while (true) {
			var x = nextUnless(TNewLine);
			switch (x) {
				case TOp(op):
					var prec = exprBinaryPrecedence(op);
					if (isBinaryOp(op) && prec >= p) {
						var q = 1 + prec;
						var t1 = numExprExp(q);
						t = NEBinaryOp(op, t, t1 );
					} else {
						returnToken(x);
						break;
					}
				default:
					returnToken(x);
					break;
			}
		}

		return t;
	}

	/*
Eparser is
		   var t : Tree
		   t := Exp( 0 )
		   expect( end )
		   return t
	*/
	function parseNumericExpression(optional=false):NumericExpression {
		var x = numExprExp(0);
		if (x == null && !optional) {
			error("Expected numerical expression");
		}
		return x;
	}

	function parseNumericExpressionOld():NumericExpression {
		var top:NumericExpression = null;

		var tk = nextUnless(TNewLine);

		if (tk == TNewLine) {
			unexpected(TNewLine);
		}

		while (tk != TNewLine) {
			switch (tk) {
				case TBrOpen:
				case TBrClose:
				case TId(ident):
					top = NEIdent(ident);
				case TOp("!"):
					top = NEUnaryOp("!", parseNumericExpression());
				case TOp(op):
					if (top == null)
						error("Binary operator requires left hand operand");
					top = NEBinaryOp(op, top, parseNumericExpression());
				case TNumber(value):
					top = NELiteral(value);
				case TComma:
					break;
				default:
					break;
			}

			tk = nextUnless(TNewLine);
		}

		returnToken(tk);

		// trace('Effect expression ${top}');
		return top;
	}

	function parseEffect(state:String, alignment):Effect {
		//        ensure(TOp("="));

		return {state: state, expression: parseNumericExpression()};
	}

	function parseParameter(name:String, alignment):Parameter {
		//        ensure(TColon);

		return {name: name, expression: parseNumericExpression()};
	}

	function parseCall(name:String, alignment):Call {
		//        ensure(TColon);

		var arguments = [];
		while (!maybe(TPClose)) {
			arguments.push(parseNumericExpression());
			maybe(TComma);
		}
		return {name: name, arguments: arguments};
	}

	function parseDeclLine(alignment:Int, declarations:Array<Declaration>):Declaration {
		var x = parseDecl(alignment, declarations);
		ensure(TNewLine);
		return x;
	}

	function parseSideCondition() {
		return if (maybe(TQuestion)) {
			SCIf(parseNumericExpression());
		} else if (maybe(TOp("->"))) {
			SCWhile(parseNumericExpression());
		} 
		else null;
	}

	function parseDecl(baseAlignment:Int, declarations:Array<Declaration>):Declaration {
		//        trace ('Parsing decl');
		switch (next()) {
			case TId(id):
				switch (id) {
					case "const":
						var name = ident();
						ensure(TColon);
						var type = parseType();
						ensure(TOp("="));
						var value = parseNumericExpression();
						return DVariable(VKConstant, name, type, value);
					case "param":
						var name = ident();
						ensure(TColon);
						var type = parseType();
						return DVariable(VKParameter, name, type, null);
					case "var":
						var name = ident();
						ensure(TColon);
						var type = parseType();
						return DVariable(VKLocal, name, type, null);
					case "abstract":
						var name = ident();
						ensure(TNewLine);
						var methods = [];
						var alignment = 0;
						while ((alignment = peekAlignment()) > baseAlignment) {
							switch (next()) {
								case TId(s):
									methods.push(parseMethod(s, alignment));
								case var x:
									trace('Something else ${x}');
							}
						}
						return DAbstract(name, methods);
					case "sequence", "first", "one", "all":
						var name = ident();
						var parallel = id == "one" || id == "all";
						var all = id == "sequence" || id == "all";

						var reset = false;
						var continued = false;
						var looped = false;

						while (maybe(TColon)) {
							var flag = ident();
							switch (flag) {
								case "restart": reset = true;
								case "reset": reset = true;
								case "continue": continued = true;
								case "loop": looped = true;
								default: unexpected(TId(flag));
							}
						}

						
						var sideCondition = parseSideCondition();

						ensure(TNewLine);

						var children = [];
						var alignment = 0;
						while ((alignment = peekAlignment()) > baseAlignment) {
							switch (next()) {
								case TQuestion:
									trace('Pushing conditional');
									children.push(BConditional(parseNumericExpression()));
									ensure(TNewLine);
								case TId(s):
									if (s == "sequence") {
										returnToken(TId(s));

										var d = parseDecl(alignment, declarations);
										switch (d) {
											case DSequence(childName, _, _, _, _, _, _, childSideCondition):
												children.push(BChild(childName, childSideCondition, []));
												declarations.push(d);
											default:
										}
									} else {
										var expr = null;
										var decorators = [];

										if (maybe(TPOpen)) {
											var params = 1;
											var ids = [];

											decorators.push({name: s});

											while (params > 0) {
												var n = next();

												switch (n) {
													case TPOpen:
														params++;
														decorators.push({name: ids.pop()});
													case TPClose: params--;
													case TId(id): ids.push(id);
													default: unexpected(n);
												}
											}
											if (ids.length != 1)
												error("No task");
											s = ids.pop();

											decorators.reverse();
										}
										var sidec = parseSideCondition();
										children.push(BChild(s, sidec, decorators));
										ensure(TNewLine);
									}
								case var x:
									trace('Something else ${x}');
							}
						}

						// sequence breed
						return DSequence(name, parallel, all, reset, continued, looped, children, sideCondition);
					case "operator":
						var name = ident();

						var condition = null;
						if (maybe(TColon)) {
							condition = parseBooleanExpression();
						}

						ensure(TNewLine);

						var effects = [];
						var parameters = [];
						var calls = [];
						var alignment = 0;
						while ((alignment = peekAlignment()) > baseAlignment) {
							switch (next()) {
								case TId(s):
									if (maybe(TColon)) {
										parameters.push(parseParameter(s, alignment));
										ensure(TNewLine);
									} else if (maybe(TOp("="))) {
										effects.push(parseEffect(s, alignment));
										ensure(TNewLine);
									} else if (maybe(TPOpen)) {
										calls.push(parseCall(s, alignment));
										ensure(TNewLine);
									}
								case var x:
									trace('Something else ${x}');
							}
						}

						return DOperator(name, condition, effects, parameters, calls);

					case "action", "async":
						var name = ident();

						var condition = null;
						if (maybe(TColon)) {
							condition = parseBooleanExpression();
						}

						ensure(TNewLine);

						var effects = [];
						var parameters = [];
						var calls = [];
						var alignment = 0;
						while ((alignment = peekAlignment()) > baseAlignment) {
							switch (next()) {
								case TId(s):
									if (maybe(TColon)) {
										parameters.push(parseParameter(s, alignment));
										ensure(TNewLine);
									} else if (maybe(TOp("="))) {
										effects.push(parseEffect(s, alignment));
										ensure(TNewLine);
									} else if (maybe(TPOpen)) {
										calls.push(parseCall(s, alignment));
										ensure(TNewLine);
									}
								case var x:
									trace('Something else ${x}');
							}
						}

						return DAction(name, id == "async", condition, effects, parameters, calls);
					default:
						return unexpected(TId(id));
				}

			case var tk:
				return unexpected(tk);
		}
		return null;
	}

	#if false
	function parseDeclOld() {
		var attr = attributes();
		var pmin = this.pos;

		switch (token()) {
			case TId("interface"):
				var name = ident();
				ensure(TBrOpen);
				var fields = [];
				while (true) {
					var tk = token();
					if (tk == TBrClose)
						break;
					push(tk);
					fields.push(parseField());
				}
				ensure(TSemicolon);
				return {pos: makePos(pmin), kind: DInterface(name, attr, fields)};
			case TId("enum"):
				var name = ident();
				ensure(TBrOpen);
				var values = [];
				if (!maybe(TBrClose))
					while (true) {
						switch (token()) {
							case TString(str): values.push(str);
							case var tk: unexpected(tk);
						}
						switch (token()) {
							case TBrClose: break;
							case TComma: continue;
							case var tk: unexpected(tk);
						}
					}
				ensure(TSemicolon);
				return {pos: makePos(pmin), kind: DEnum(name, attr, values)};
			case TId("typedef"):
				var name = ident();
				var typeStr = "";
				var first = true;
				while (!maybe(TSemicolon)) {
					if (!first)
						typeStr = typeStr + " ";
					first = false;
					var tk = token();
					switch (tk) {
						case TId(id):
							typeStr = typeStr + id;
						default:
							throw("Unknown type " + tk);
					}
				}
				typeDefs[name] = typeStr;
				return {pos: makePos(pmin), kind: DTypeDef(name, attr, typeStr)};
			case TId(name):
				if (attr == null) {
					throw "attributes error on " + name;
				}
				if (attr.length > 0) {
					trace(name + " : " + attributes);
					throw "attributes should be zero on " + name;
				}
				ensure(TId("implements"));
				var intf = ident();
				ensure(TSemicolon);
				return {pos: makePos(pmin), kind: DImplements(name, intf)};

			case var tk:
				return unexpected(tk);
		}
	}

	function attributes() {
		if (!maybe(TBkOpen))
			return [];
		var attrs = [];
		while (true) {
			var attr = switch (ident()) {
				case "Value": AValue;
				case "Ref": ARef;
				case "Deref": ADeref;
				case "Const": AConst;
				case "AddressOf": AAddressOf;
				case "Clone": AClone;
				case "NoDelete": ANoDelete;
				case "Static": AStatic;
				case "Virtual": AVirtual;
				case "ReadOnly": AReadOnly;
				case "CStruct": ACStruct;
				case "Indexed": AIndexed;
				case "Out": AOut;
				case "HString": AHString;
				case "Synthetic": ASynthetic;
				case "Return": AReturn;
				case "CObject": ACObject;
				case "STL": ASTL;
				case "Local": ALocal;
				case "Ignore": AIgnore;

				case "Throw":
					ensure(TOp("="));
					AThrow(switch (token()) {
						case TString(s): s;
						case var tk: unexpected(tk);
					});
				case "Validate":
					ensure(TOp("="));
					AValidate(switch (token()) {
						case TString(s): s;
						case var tk: unexpected(tk);
					});
				case "Internal":
					ensure(TOp("="));
					AInternal(switch (token()) {
						case TString(s): s;
						case var tk: unexpected(tk);
					});
				case "New":
					ensure(TOp("="));
					ANew(switch (token()) {
						case TString(s): s;
						case var tk: unexpected(tk);
					});
				case "Delete":
					ensure(TOp("="));
					ADelete(switch (token()) {
						case TString(s): s;
						case var tk: unexpected(tk);
					});
				case "Get":
					ensure(TOp("="));
					AGet(switch (token()) {
						case TString(s): s;
						case var tk: unexpected(tk);
					});
				case "Cast":
					ensure(TOp("="));
					ACast(switch (token()) {
						case TString(s): s;
						case var tk: unexpected(tk);
					});
				case "Set":
					ensure(TOp("="));
					ASet(switch (token()) {
						case TString(s): s;
						case var tk: unexpected(tk);
					});
				case "Prefix":
					ensure(TOp("="));
					APrefix(switch (token()) {
						case TString(s): s;
						case var tk: unexpected(tk);
					});
				case "ReturnArray":
					ensure(TOp("="));
					ensure(TPOpen);
					var pIdx = switch (token()) {
						case TId(s): s;
						case TString(s): s;
						case var tk: unexpected(tk);
					};
					ensure(TComma);
					var lIdx = switch (token()) {
						case TId(s): s;
						case TString(s): s;
						case var tk: unexpected(tk);
					};
					ensure(TPClose);
					AReturnArray(pIdx, lIdx);
				case "JSImplementation":
					ensure(TOp("="));
					AJSImplementation(switch (token()) {
						case TString(s): s;
						case var tk: unexpected(tk);
					});
				case "Operator":
					ensure(TOp("="));
					AOperator(switch (token()) {
						case TString(s): s;
						case var tk: unexpected(tk);
					});
				case "Substitute":
					ensure(TOp("="));
					ASubstitute(switch (token()) {
						case TString(s): s;
						case var tk: unexpected(tk);
					});
				case var attr:
					error("Unsupported attribute " + attr);
					null;
			}
			attrs.push(attr);
			if (!maybe(TComma))
				break;
		}
		ensure(TBkClose);

		return attrs;
	}

	function type(attrs:Array<Attrib> = null):Type {
		// Type defs
		var original_id = ident();
		var id = original_id;
		var remapped = false;
		while (typeDefs.exists(id)) {
			id = typeDefs[id];
			remapped = true;
		}
		if (remapped && attrs != null) {
			attrs.push(ARemap(original_id, id));
		}

		var t = switch (id) {
			case "void": TVoid;
			case "byte", "uchar", "char": TChar;
			case "float": TFloat;
			case "double": TDouble;
			case "long", "int": TInt; // long ensures 32 bits
			case "short", "uint16": TShort;
			case "int64": TInt64;
			case "uint": TUInt;
			case "boolean", "bool": TBool;
			case "any": TAny;
			case "VoidPointer", "VoidPtr": TVoidPtr;
			case "bytes": TBytes;
			case "string", "String": THString;
			case "struct": TStruct; // Doesn't work yet
			case "float2": TVector(TFloat, 2);
			case "float3": TVector(TFloat, 3);
			case "float4": TVector(TFloat, 4);
			case "int2": TVector(TInt, 2);
			case "int3": TVector(TInt, 3);
			case "int4": TVector(TInt, 4);
			case "double2": TVector(TDouble, 2);
			case "double3": TVector(TDouble, 3);
			case "double4": TVector(TDouble, 4);
			case "dynamic": TDynamic;
			default:
				TCustom(id);
		};
		if (maybe(TBkOpen)) {
			if (maybe(TBkClose)) {
				t = TArray(t, null);
			} else {
				var size = ident();
				ensure(TBkClose);
				t = TArray(t, size);
			}
		} else if (maybe(TAsterisk)) {
			t = TPointer(t);
		}
		return t;
	}

	function parseField():Field {
		var attr = attributes();
		var pmin = this.pos;

		if (maybe(TId("attribute"))) {
			var t = type(attr);
			var name = ident();
			ensure(TSemicolon);
			return {name: name, kind: FAttribute({t: t, attr: attr}), pos: makePos(pmin)};
		}

		if (maybe(TId("const"))) {
			var type = type();
			var name = ident();
			ensure(TOp("="));
			var value = tokenString(token());
			ensure(TSemicolon);
			return {name: name, kind: DConst(name, type, value), pos: makePos(pmin)};
		}

		var tret = type();
		var name = ident();
		ensure(TPOpen);
		var args = [];
		if (!maybe(TPClose)) {
			while (true) {
				var attr = attributes();
				var opt = maybe(TId("optional"));
				var t = type();
				var name = ident();
				args.push({name: name, t: {t: t, attr: attr}, opt: opt});
				switch (token()) {
					case TPClose:
						break;
					case TComma:
						continue;
					case var tk:
						unexpected(tk);
				}
			}
		}
		ensure(TSemicolon);
		return {name: name, kind: FMethod(args, {attr: attr, t: tret}), pos: makePos(pmin)};
	}
	#end
}
