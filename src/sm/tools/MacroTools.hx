package sm.tools;


#if macro

import haxe.macro.Expr;
import tink.macro.Exprs;

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

#end