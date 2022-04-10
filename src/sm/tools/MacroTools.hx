package sm.tools;


#if macro

import haxe.macro.Expr;
using tink.MacroApi;
import haxe.macro.Context;

 function exprConstString(s:String) : Expr{
    return Exprs.at(EConst(CString(s)));
}

function exprConstInt(i:Int) : Expr{
    return Exprs.at(EConst(CInt(Std.string(i))));
}

 function exprID(s:String): Expr {
    return EConst(CIdent(s)).at();
}

 function exprCall(method:String, ?params:Array<Expr>) : Expr {
    return Exprs.call(Exprs.at(EConst(CIdent(method))), params);
}



 function exprTrue():Expr {
    return macro true;
}

 function exprRet(e:Expr) : Expr{
    return macro return $e;
}

 function exprIf(c:Expr, e:Expr) {
    return Exprs.at(EIf(c, e, null));
}

 function exprEq(a:Expr, b:Expr) : Expr{
    return macro $a == $b;
}

 function exprEmptyBlock() : Expr{
    return macro {};
}

function exprFor(ivar:Expr, len:Expr, expr:Expr) : Expr{
    return macro for ($ivar in 0...$len) $expr;
}

function getStringValue(e:Expr):String {
    var str = e.getString();
    if (str.isSuccess())
        return str.sure();
    switch (e.expr) {
        case EConst(c):
            switch (c) {
                case CString(s, kind): return s;
                case CIdent(s): return s;
                case CFloat(f): return f;
                case CInt(v): return v;
                default:
            }
        default:
    }
    return null;
}

function makeField(name, access, func : Function) : Field{
     return {
        name:name,
        doc: null,
        meta: [],
        access: access,
        kind: FFun(func),
        pos: Context.currentPos()
    };
}
#end