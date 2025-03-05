package ai.macro;

// Tiny selection of tink_macro to avoid dependency
// https://github.com/haxetink/tink_macro
#if macro
import haxe.macro.Expr;
import haxe.macro.MacroStringTools;
import haxe.macro.Context;
import haxe.macro.Printer;
import haxe.macro.Type;

class Extensions {
	static var _printer:Printer;

	inline static function printer():Printer {
		if (_printer == null)
			_printer = new Printer();
		return _printer;
	}

	static public function toString(t:ComplexType)
		return printer().printComplexType(t);

	static public inline function sanitize(pos:Position)
		return if (pos == null) Context.currentPos(); else pos;

	static public inline function at(e:ExprDef, ?pos:Position)
		return {
			expr: e,
			pos: sanitize(pos)
		};

	static public function asTypePath(s:String, ?params):TypePath {
		var parts = s.split('.');
		var name = parts.pop(), sub = null;
		if (parts.length > 0 && parts[parts.length - 1].charCodeAt(0) < 0x5B) {
			sub = name;
			name = parts.pop();
			if (sub == name)
				sub = null;
		}
		return {
			name: name,
			pack: parts,
			params: params == null ? [] : params,
			sub: sub
		};
	}

	static public inline function asComplexType(s:String, ?params)
		return TPath(asTypePath(s, params));

	static public inline function toMBlock(exprs:Array<Expr>, ?pos)
		return at(EBlock(exprs), pos);

	static public inline function toBlock(exprs:Iterable<Expr>, ?pos)
		return toMBlock(Lambda.array(exprs), pos);

	static public inline function binOp(e1:Expr, e2, op, ?pos)
		return at(EBinop(op, e1, e2), pos);

	static public inline function assign(target:Expr, value:Expr, ?op:Binop, ?pos:Position)
		return binOp(target, value, op == null ? OpAssign : OpAssignOp(op), pos);

	static public inline function field(x:Expr, member:String, ?pos):Expr {
		return at(EField(x, member), pos);
	}

	static public function isVar(field:haxe.macro.Type.ClassField)
		return switch (field.kind) {
			case FVar(_, _): true;
			default: false;
		}

	static public function getString(e:Expr)
		return switch (e.expr) {
			case EConst(c):
				switch (c) {
					case CString(string): string;
					default: null;
				}
			default: null;
		}

	static public inline function define(name:String, ?init:Expr, ?typ:ComplexType, ?pos:Position)
		return at(EVars([{name: name, type: typ, expr: init}]), pos);

	static public function getMeta(type:Type)
		return switch type {
			case TInst(_.get().meta => m, _): [m];
			case TEnum(_.get().meta => m, _): [m];
			case TAbstract(_.get().meta => m, _): [m];
			case TType(_.get() => t, _): [t.meta].concat(getMeta(t.type));
			case TLazy(f): getMeta(f());
			default: [];
		}

	static public function toMap(m:Metadata) {
		var ret = new Map<String, Array<Array<Expr>>>();
		if (m != null)
			for (meta in m) {
				if (!ret.exists(meta.name))
					ret.set(meta.name, []);
				ret.get(meta.name).push(meta.params);
			}
		return ret;
	}

	static public inline function toExpr(v:Dynamic, ?pos:Position)
		return Context.makeExpr(v, sanitize(pos));

	static public function method(name:String, ?pos, ?isPublic = true, f:Function) {
		var f:Field = {
			name: name,
			pos: if (pos == null) f.expr.pos else pos,
			kind: FFun(f),
			access: isPublic ? [APublic] : [],
		};
		return f;
	}

	static public inline function toArg(name:String, ?t, ?opt = false, ?value = null):FunctionArg {
		return {
			name: name,
			opt: opt,
			type: t,
			value: value
		};
	}

	static public inline function func(e:Expr, ?args:Array<FunctionArg>, ?ret:ComplexType, ?params, ?makeReturn = true):Function {
		return {
			args: args == null ? [] : args,
			ret: ret,
			params: params == null ? [] : params,
			expr: if (makeReturn) at(EReturn(e), e.pos) else e
		}
	}

	static public function drill(parts:Array<String>, ?pos:Position, ?target:Expr) {
		if (target == null)
			target = at(EConst(CIdent(parts.shift())), pos);
		for (part in parts)
			target = field(target, part, pos);
		return target;
	}

	static public inline function resolve(s:String, ?pos)
		return drill(s.split('.'), pos);

	static public function getter(field:String, ?pos, e:Expr, ?t:ComplexType)
		return method('get_' + field, pos, false, func(e, t));

	static public function setter(field:String, ?param = 'param', ?pos, e:Expr, ?t:ComplexType)
		return method('set_' + field, pos, false, func(toBlock([e, resolve(param, pos)], pos), [toArg(param, t)], t));

	static public function getIdent(e:Expr)
		return switch (e.expr) {
			case EConst(c):
				switch (c) {
					case CIdent(id): id;
					default: null;
				}
			default:
				null;
		}

	static public function prop(name:String, t:ComplexType, pos, ?noread = false, ?nowrite = false):Field {
		var ret:Field = {
			name: name,
			pos: pos,
			access: [APublic],
			kind: FProp(noread ? 'null' : 'get', nowrite ? 'null' : 'set', t),
		}
		return ret;
	}

	static public inline function call(e:Expr, ?params, ?pos)
		return at(ECall(e, params == null ? [] : params), pos);

	static public function getValues(m:Metadata, name:String)
		return if (m == null) []; else [for (meta in m) if (meta.name == name) meta.params];
	/*
		static public function lazyComplex(f:Void->Type)
			return
			  TPath({
				pack : ['tink','macro'],
				name : 'DirectType',
				params : [TPExpr(register(f).toExpr())],
				sub : null,
			  });

		static public function toComplex(type:Type, ?options:{ ?direct: Bool }):ComplexType {
			var ret =
			  if (options == null || options.direct != true)type.toComplexType();
			  else null;
			if (ret == null)
			  ret = lazyComplex(function () return type);
			return ret;
		  }
	 */
}

class ExprExtensions {
	static public inline function toString(e:Expr):String
		return new haxe.macro.Printer().printExpr(e);
}
#end
