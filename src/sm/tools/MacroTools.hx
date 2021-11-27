package sm.tools;


#if macro

import haxe.macro.Expr;
import tink.macro.Exprs;


 function exprConstString(s:String) : Expr{
    return Exprs.at(EConst(CString(s)));
}

function exprConstInt(i:Int) : Expr{
    return Exprs.at(EConst(CInt(Std.string(i))));
}

 function exprID(s:String): Expr {
    return Exprs.at(EConst(CIdent(s)));
}

 function exprCall(method:String, ?params:Array<Expr>) : Expr {
    return Exprs.call(Exprs.at(EConst(CIdent(method))), params);
}

// Tries to guess at correct overload
function exprCallField(f:Field, ?params:Array<Expr>) : Expr {

    switch(f.kind) {
        case FFun(fun):
            if (params != null && params.length > 0 && params.length > fun.args.length) {
                var tp = new Array<Expr>();
                for (i in 0...fun.args.length) {
                    tp.push(params[i + params.length - fun.args.length]);
                }
                return Exprs.call(Exprs.at(EConst(CIdent(f.name))), tp);
            }
            
        default : throw "Not a function";
    }

    return Exprs.call(Exprs.at(EConst(CIdent(f.name))), params);
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
#end