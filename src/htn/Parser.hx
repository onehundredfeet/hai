package htn;

var x : haxe.macro.Expr;


enum VariableKind {
    VKConstant;
    VKParameter;
    VKLocal;
}

enum BooleanExpression {
    BEUnaryOp(op:String, expr : BooleanExpression);
    BEBinaryOp(op:String, left : BooleanExpression, right : BooleanExpression);
    BEIdent(name:String);
    BELiteral(isTrue: Bool);
}

typedef Parameter = {
    name:String,
    value:String
}

typedef SubTask = {
    name:String,
    paramters:Array<Parameter>
}

typedef Method = {name : String, condition : BooleanExpression, subtasks : Array<SubTask>};


enum Expression {
    EVariable( kind : VariableKind,name : String, type : String, value : String );
    EAbstract(name : String, methods : Array<Method>);
    EOperator(name : String);
}


class Parser extends Lexer {
	
	var typeDefs:Map<String,String>;
    
	public function new() {
        super();
        typeDefs = new Map<String,String>();

	}

	public function parseFile(fileName:String, input:haxe.io.Input) : Array<Expression>{
		this.fileName = fileName;
		pos = 0;
		line = 1;
		char = -1;
		tokens = [];
		this.input = input;
        var declarations = new Array<Expression>();

        trace('Starting parsing...${fileName}');

        var alignment = 0;

		while (true) {
			var tk = next(false);
            //trace ('token: ${tokenString(tk)}');
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
            trace('Parsing ${tk}');
			
            if (alignment == 0) {
                returnToken(tk);
                declarations.push(parseDeclLine());
            } else {
                error('Declarations should not have whitespace in front of them ${tk}');
            }
		}
		return declarations;
	}


   

    function parseBooleanExpression() : BooleanExpression {
        
        
        
        var top : BooleanExpression = null;

        var tk = nextUnless(TNewLine);

        trace('First tk is ${tk}');
        if (tk == TNewLine) {
            returnToken(tk);
            return BELiteral(true);
        }

        while (tk != TNewLine) {
            switch(tk) {
                case TBrOpen:
                case TBrClose:
                case TId(ident):
                    if (ident == "true") top = BELiteral(true);
                    else if (ident == "false") top = BELiteral(false);
                    else top = BEIdent(ident);
                case TOp("!"):
                    top = BEUnaryOp("!", parseBooleanExpression() );   
                case TOp(op):
                    if (top == null) error("Binary operator requires left hand operand");
                    top = BEBinaryOp(op, top, parseBooleanExpression() );
                default:
                    break;
            }

            trace('Top is now ${top}');

            tk = nextUnless(TNewLine);
        }

        returnToken(tk);

        trace('Boolean expression ${top}');
        return top;
    }

    function parseCallArgument() : Parameter {
        var x = ident();
        ensure(TColon);
        var y = ident();
        trace('Argument found ${x} : ${y}');
        return {name:x, value:y};
    }

    function parseSubtask(name:String, alignment) : SubTask {
        if (maybe(TPOpen)) {
            trace("Subtask has parameters");
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
        ensure(TNewLine);
        return {name:name, paramters: []};
    }

    function parseMethod(name:String, alignment) : Method {
        trace ('Parsing method ${name}');
        ensure(TColon);
        trace('Parsing Condition');
        var conditions = parseBooleanExpression();
        trace('End of line');
        ensure(TNewLine);

        trace('Now subtasks');
        var subAlign = 0;
        var subTasks = new Array<SubTask>();

        trace('Next Align ${peekAlignment()}');
        while ((subAlign=peekAlignment()) > alignment) {
            trace("SubTask?");
            switch( next() ) {
                case TId(s):
                    subTasks.push(parseSubtask(s, subAlign));
                case var x:
                    trace('Something else ${x}');
                    
            }
           
        }
        return {name:name, condition: conditions, subtasks: subTasks};
    }

    function parseDeclLine() : Expression {
        var x = parseDecl();
        ensure(TNewLine);   
        return x;
    }
    function parseDecl() :Expression {
        trace ('Parsing decl');
        switch (next()) {
            case TId("const"):
                var name = ident();
                ensure(TColon);
                var type = ident();
                ensure(TOp("="));
                var value = ident();
                trace('Parsing const ${name} : ${type} [ ${value} ]');
                return EVariable( VKConstant, name, type, value);
            case TId("param"):
                var name = ident();
                ensure(TColon);
                var type = ident();
                trace('Parsing param ${name} : ${type}');
                return EVariable( VKParameter, name, type, null);
            case TId("var"):
                var name = ident();
                ensure(TColon);
                var type = ident();
                trace('Parsing var ${name} : ${type}');
                return EVariable( VKLocal, name, type, null);
            case TId("abstract"):
                var name = ident();
                ensure(TNewLine);
                var methods = [];
                var alignment = 0;
                while ((alignment=peekAlignment()) > 0) {
                    switch( next() ) {
                        case TId(s):
                            methods.push(parseMethod(s, alignment));
                        case var x:
                            trace('Something else ${x}');
                            
                    }
                   
                }
                trace('Parsing abstract ${name} : ${methods}');
                return EAbstract(name, methods);
            case TId("operator"):
                var name = ident();
                return EOperator(name);
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
					if (!first) typeStr = typeStr + " ";
					first = false;
					var tk = token();
					switch(tk) {
						case TId(id):
							typeStr = typeStr + id;
						default:
							throw ("Unknown type " + tk);
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
				case "Deref":ADeref;
				case "Const": AConst;
				case "AddressOf": AAddressOf;
				case "Clone" : AClone;
				case "NoDelete": ANoDelete;
				case "Static": AStatic;
				case "Virtual": AVirtual;
				case "ReadOnly": AReadOnly;
				case "CStruct": ACStruct;
				case "Indexed": AIndexed;
				case "Out": AOut;
				case "HString" : AHString;
				case "Synthetic": ASynthetic;
				case "Return": AReturn;
				case "CObject": ACObject;
				case "STL" : ASTL;
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
						case TId(s):s;
						case TString(s): s;
						case var tk: unexpected(tk);
					};
					ensure(TComma);
					var lIdx = switch (token()) {
						case TId(s):s;
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

	function type(attrs : Array<Attrib> = null):Type {
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
			case "struct": TStruct;  // Doesn't work yet
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
