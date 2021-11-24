package sm.tools;


#if macro

import haxe.macro.Expr;
import tink.macro.Exprs;


 function exprConstString(s:String) {
    return Exprs.at(EConst(CString(s)));
}

function exprConstInt(i:Int) {
    return Exprs.at(EConst(CInt(Std.string(i))));
}

 function exprID(s:String) {
    return Exprs.at(EConst(CIdent(s)));
}

 function exprCall(method:String, ?params:Array<Expr>) {
    return Exprs.call(Exprs.at(EConst(CIdent(method))), params);
}

 function exprTrue():Expr {
    return macro true;
}

 function exprRet(e:Expr) {
    return macro return $e;
}

 function exprIf(c:Expr, e:Expr) {
    return Exprs.at(EIf(c, e, null));
}

 function exprEq(a:Expr, b:Expr) {
    return macro $a == $b;
}

 function exprEmptyBlock() {
    return macro {};
}

function exprFor(ivar:Expr, len:Expr, expr:Expr) {
    return macro for ($ivar in 0...$len) $expr;
}
#end