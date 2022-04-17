package ai.tools;


private enum Token {
	TEof;
	TId(s:String);
	TPOpen;
	TPClose;
	TBrOpen;
	TBrClose;
	TBkOpen;
	TBkClose;
	TAsterisk;
	TSemicolon;
	TColon;
	TComma;
	TPeriod;
	TOp(op:String);
	TNumber(value:String);
	TString(str:String);
	THash;
	// White Space
	TTab;
	TSpace;
	TQuestion;
	TNewLine;
}

class Lexer {
    public var line:Int;

	var input:haxe.io.Input;
	var char:Int;
	var ops:Array<Bool>;
	var idents:Array<Bool>;
	var tokens:Array<Token>;
	var pos = 0;
	var fileName:String;

	public function new() {
		var opChars = "+*/-=!><&|^%~";
		var identChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_";
		idents = new Array();
		ops = new Array();

		for (i in 0...identChars.length)
			idents[identChars.charCodeAt(i)] = true;
		for (i in 0...opChars.length)
			ops[opChars.charCodeAt(i)] = true;
	}

    function tokenString(tk) {
		return switch (tk) {
			case TEof: "<eof>";
			case TId(id): id;
			case TPOpen: "(";
			case TPClose: ")";
			case TAsterisk: "*";
			case TBkOpen: "[";
			case TBkClose: "]";
			case TBrOpen: "{";
			case TBrClose: "}";
			case TComma: ",";
			case THash: "#";
			case TSemicolon: ";";
			case TColon: ":";
			case TOp(op): op;
			case TString(str): '"' + str + '"';
			case TTab: "<tab>";
			case TNewLine: "<line>";
			case TSpace: "<space>";
			case TPeriod: ".";
			case TQuestion: "?";
			case TNumber(value): value;
		}
	}

	function discardLine() {
		var tk = next(false);
		while(tk != TNewLine) {
			if (tk == TEof) {
				returnToken(TEof);
				break;
			}
			tk = next(false);
		}
	}
    // --- Lexing

	function invalidChar(c:Int) {
		error("Invalid char " + c + "(" + String.fromCharCode(c) + ")");
	}

	function error(msg:String) {
		throw msg + " line " + line;
	}

	function unexpected(tk, et : Token = null):Dynamic {
		if (et != null) {
			error("Unexpected " + tokenString(tk) + " expected " + tokenString(et));
		} else {
			error("Unexpected " + tokenString(tk));
		}
		return null;
	}

	inline function returnToken(tk) {
		//trace('Return token to ${tokens}');
		tokens.unshift(tk);
	}

	function ensure(tk, skipWhiteSpace : Bool = true) {
		var t = token();	// oldest token
		if (skipWhiteSpace)  {
			while (isWhiteSpace(t)) {
				if (t == tk || std.Type.enumEq(t, tk)) {
					break;
				}

				t = token();
			} 
		}

		if (t != tk && !std.Type.enumEq(t, tk))
			unexpected(t, tk);
	}

	function isWhiteSpace( t : Token ) {
		return t == TNewLine || t == TTab || t == TSpace;
	}

	function maybe(tk, skipWhiteSpace : Bool = true) {
		var rejected = [];

		var t = token();	// oldest token
		if (skipWhiteSpace) {
			while (isWhiteSpace(t)) {
				rejected.push(t);
				t = token();
			}	
		}

		if (t == tk || std.Type.enumEq(t, tk))
			return true;
		returnToken(t); // youngest first
		while (rejected.length > 0) {
			returnToken(rejected.pop());	// next youngest
		}
		return false;
	}

	function ident() {
		var tk = next();
		switch (tk) {
			case TId(id):
				return id;
			default:
				unexpected(tk);
				return null;
		}
	}

	function peekAlignment() {
		var count = 0;
		var x = null;
		while ((x = next(false)) == TSpace) count++;
		
		returnToken(x);
		var alignment = count;
		while(count > 0) {
			returnToken( TSpace );
			count--;
		}
		return alignment;
	}
	function readChar() {
		pos++;
		return try input.readByte() catch (e:Dynamic) 0;
	}

	function next(skipWhiteSpace : Bool = true):Token {
		//trace ('Next from ${tokens}');
		var t = token();	// oldest token
		//trace ('Next is ${t}');

		if (skipWhiteSpace) 
			while (isWhiteSpace(t)) t = token();
		return t;
	}

	function nextUnless(tk : Token, skipWhiteSpace : Bool = true):Token {
		//trace ('Next from ${tokens}');
		var t = token();	// oldest token
		//trace ('Next is ${t}');

		if (skipWhiteSpace) {
			while (isWhiteSpace(t)){
				if (t == tk || std.Type.enumEq(t, tk)) return t;
				t = token();
			} 
		}
		return t;
	}

	function token():Token {
		if (tokens.length > 0) {
			var x = tokens.shift();	// oldest token is at the beginning
			return x;
		}
		var char;
		if (this.char < 0)
			char = readChar();
		else {
			char = this.char;
			this.char = -1;
		}
		while (true) {
			switch (char) {
				case 0:
					return TEof;
				case  9:
					return TTab;
				case 32:
					return TSpace;
				case 13: // space, CR
				case 10:
					line++; // LF
					return TNewLine;
				case 35: return THash;
				case 48,49,50,51,52,53,54,55,56,57:
					var numStr = String.fromCharCode(char);

					while( true ) {
						char = readChar();
						if (char >= 48 && char <= 57) numStr += String.fromCharCode(char);
						if (char == 46) numStr +=  String.fromCharCode(char);
						this.char = char;
						break;
					}
					return TNumber(numStr);
				/*			case 48,49,50,51,52,53,54,55,56,57: // 0...9
					var n = (char - 48) * 1.0;
					var exp = 0.;
					while( true ) {
						char = readChar();
						exp *= 10;
						switch( char ) {
						case 48,49,50,51,52,53,54,55,56,57:
							n = n * 10 + (char - 48);
						case 46:
							if( exp > 0 ) {
								// in case of '...'
								if( exp == 10 && readChar() == 46 ) {
									push(TOp("..."));
									var i = Std.int(n);
									return TConst( (i == n) ? CInt(i) : CFloat(n) );
								}
								invalidChar(char);
							}
							exp = 1.;
						case 120: // x
							if( n > 0 || exp > 0 )
								invalidChar(char);
							// read hexa
							#if haxe3
							var n = 0;
							while( true ) {
								char = readChar();
								switch( char ) {
								case 48,49,50,51,52,53,54,55,56,57: // 0-9
									n = (n << 4) + char - 48;
								case 65,66,67,68,69,70: // A-F
									n = (n << 4) + (char - 55);
								case 97,98,99,100,101,102: // a-f
									n = (n << 4) + (char - 87);
								default:
									this.char = char;
									return TConst(CInt(n));
								}
							}
							#else
							var n = haxe.Int32.ofInt(0);
							while( true ) {
								char = readChar();
								switch( char ) {
								case 48,49,50,51,52,53,54,55,56,57: // 0-9
									n = haxe.Int32.add(haxe.Int32.shl(n,4), cast (char - 48));
								case 65,66,67,68,69,70: // A-F
									n = haxe.Int32.add(haxe.Int32.shl(n,4), cast (char - 55));
								case 97,98,99,100,101,102: // a-f
									n = haxe.Int32.add(haxe.Int32.shl(n,4), cast (char - 87));
								default:
									this.char = char;
									// we allow to parse hexadecimal Int32 in Neko, but when the value will be
									// evaluated by Interpreter, a failure will occur if no Int32 operation is
									// performed
									var v = try CInt(haxe.Int32.toInt(n)) catch( e : Dynamic ) CInt32(n);
									return TConst(v);
								}
							}
							#end
						default:
							this.char = char;
							var i = Std.int(n);
							return TConst( (exp > 0) ? CFloat(n * 10 / exp) : ((i == n) ? CInt(i) : CFloat(n)) );
						}
				}*/
				case 58:
					return TColon;
				case 59:
					return TSemicolon;
				case 40:
					return TPOpen;
				case 41:
					return TPClose;
				case 44:
					return TComma;
				case 46: return TPeriod;
				/*			case 46:
					char = readChar();
					switch( char ) {
					case 48,49,50,51,52,53,54,55,56,57:
						var n = char - 48;
						var exp = 1;
						while( true ) {
							char = readChar();
							exp *= 10;
							switch( char ) {
							case 48,49,50,51,52,53,54,55,56,57:
								n = n * 10 + (char - 48);
							default:
								this.char = char;
								return TConst( CFloat(n/exp) );
							}
						}
					case 46:
						char = readChar();
						if( char != 46 )
							invalidChar(char);
						return TOp("...");
					default:
						this.char = char;
						return TDot;
				}*/
				case 0x2A: 
					return TAsterisk;
				case 123:
					return TBrOpen;
				case 125:
					return TBrClose;
				case 91:
					return TBkOpen;
				case 93:
					return TBkClose;
				case 39: // back tick ` or single quote ' // ??
					return TString(readString(39));
				case 34: // double quote
					return TString(readString(34));
				case 63: return TQuestion;
				//			case 58: return TDoubleDot;
				case '='.code:
					char = readChar();
					if (char == '='.code)
						return TOp("==");
					else if (char == '>'.code)
						return TOp("=>");
					this.char = char;
					return TOp("=");
				default:
					if (ops[char]) {
						var op = String.fromCharCode(char);
						var prev = -1;
						while (true) {
							char = readChar();
							if (!ops[char] || prev == '='.code) {
								if (op.charCodeAt(0) == '/'.code)
									return tokenComment(op, char);
								this.char = char;
								return TOp(op);
							}
							prev = char;
							op += String.fromCharCode(char);
						}
					}
					if (idents[char]) {
						var id = String.fromCharCode(char);
						while (true) {
							char = readChar();
							if (!idents[char]) {
								this.char = char;
								return TId(id);
							}
							id += String.fromCharCode(char);
						}
					}
					invalidChar(char);
			}
			char = readChar();
		}
		return null;
	}

	function tokenComment(op:String, char:Int) {
		var c = op.charCodeAt(1);
		var s = input;
		if (c == '/'.code) { // comment
			try {
				while (char != '\r'.code && char != '\n'.code) {
					pos++;
					char = s.readByte();
				}
				this.char = char;
			} catch (e:Dynamic) {}
			return token();
		}
		if (c == '*'.code) {/* comment */
			var old = line;
			if (op == "/**/") {
				this.char = char;
				return token();
			}
			try {
				while (true) {
					while (char != '*'.code) {
						if (char == '\n'.code)
							line++;
						pos++;
						char = s.readByte();
					}
					pos++;
					char = s.readByte();
					if (char == '/'.code)
						break;
				}
			} catch (e:Dynamic) {
				line = old;
				error("Unterminated comment");
			}
			return token();
		}
		this.char = char;
		return TOp(op);
	}

	function readString(until) {
		var c = 0;
		var b = new haxe.io.BytesOutput();
		var esc = false;
		var old = line;
		var s = input;
		while (true) {
			try {
				pos++;
				c = s.readByte();
			} catch (e:Dynamic) {
				line = old;
				error("Unterminated string");
			}
			if (esc) {
				esc = false;
				switch (c) {
					case 'n'.code:
						b.writeByte(10);
					case 'r'.code:
						b.writeByte(13);
					case 't'.code:
						b.writeByte(9);
					case "'".code, '"'.code, '\\'.code:
						b.writeByte(c);
					case '/'.code:
						b.writeByte(c);
					default:
						invalidChar(c);
				}
			} else if (c == 92)
				esc = true;
			else if (c == until)
				break;
			else {
				if (c == 10)
					line++;
				b.writeByte(c);
			}
		}
		return b.getBytes().toString();
	}
	function makePos(pmin:Int) {
		return {file: fileName, line: line, pos: pmin};
	}
}

