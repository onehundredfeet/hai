package ai.macro;


#if macro

import ai.tools.AST;
import haxe.macro.Expr;
using tink.MacroApi;
import haxe.macro.Context;
using StringTools;

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

function accumulateTagFunction( field : Field, fieldMap : Map<String, Array<Array<Expr>>>, tag :String, fmap : Map<String, Array<Field>> ) {
    if (fieldMap.exists(tag)) {
        var opNames = fieldMap.get(tag);
        for (olist in opNames) {
            for (o in olist) {
                var oname = getStringValue(o);
                var ofields = fmap.get(oname);
                if (ofields == null) {
                    ofields = new Array<Field>();
                    fmap.set(oname, ofields);
                }
                ofields.push(field);
            }
        }
    }
}

function getTagFunctions( fields : Array<Field>, tags : Array<String> ) {
    var tagToFuncMap = new  Map<String, Map<String, Array<Field>>>();

    for (t in tags) {
        tagToFuncMap.set(t, new Map<String, Array<Field>>());
    }

    fields.map((x) -> {
        if (x.kind.match(FFun(_))) {
            var y = x.meta.toMap();
            for (t in tags) {
                var map = tagToFuncMap.get(t);
                accumulateTagFunction( x, y, t, map );
            }
        }
    });

    return tagToFuncMap;
}

 function getExpressionType(et:ExpressionType) {
    switch (et) {
        case ETFloat:
            return Context.getType("Float").toComplex();
        case ETBool:
            return Context.getType("Bool").toComplex();
        case ETInt:
            return Context.getType("Int").toComplex();
        case ETUser(name):
            return Context.getType(name).toComplex();
    }
    return null;
}

 function getBinOp(op:String):Binop {
    return switch (op) {
        case "+": return Binop.OpAdd;
        case "-": return Binop.OpSub;
        case "*": return Binop.OpMult;
        case "/": return Binop.OpDiv;
        case "&": return Binop.OpBoolAnd;
        case "&&": return Binop.OpBoolAnd;
        case ">": return Binop.OpGt;
        case "<": return Binop.OpLt;
        case ">=": return Binop.OpGte;
        case "<=": return Binop.OpLte;
        case "=": return Binop.OpEq;
        case "==": return Binop.OpEq;
        default:
            Context.error('Unknown operator ${op}', Context.currentPos());
    }
}

 function getNumericExpression(ne:NumericExpression):haxe.macro.Expr {
    //		trace('NE: ${ne}');
    return switch (ne) {
        case NELiteral(value): EConst(CFloat(value)).at();
        case NEIdent(name): macro $i{name};
        case NEBinaryOp(op, left, right): EBinop(getBinOp(op), getNumericExpression(left), getNumericExpression(right)).at();
        default: Context.error('Unknown numeric expression ${ne}', Context.currentPos());
    }
}

 function getBooleanExpression(be:BooleanExpression) {
    //		trace('BE: ${be}');
    return switch (be) {
        case BELiteral(isTrue): isTrue ? macro true : macro false;
        case BEIdent(name): macro $i{name};
        case BEBinaryOp(op, left, right): EBinop(getBinOp(op), getBooleanExpression(left), getBooleanExpression(right)).at();
        default: Context.error('Unknown boolean expression ${be}', Context.currentPos());
    }
}

 function cleanIdentifier(s:String):String {
    if (s.startsWith("A_")) {
        return s.substr(2).toUpperCase();
    }
    if (s.startsWith("O_")) {
        return s.substr(2).toUpperCase();
    }
    return s.toUpperCase();
}
#end