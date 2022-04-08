package htn.macro;

#if macro

import haxe.macro.Expr;
import htn.Parser;
import haxe.macro.Context;

class HTNBuilder {
    static function generate( ast : Array<Declaration> ) {
        for(d in ast) {
            trace('${d}');
        }
    }

    public static function build(path:String):Array<Field> {
        var parse = new Parser();

        var content = try {
			sys.io.File.getBytes(path);
		} catch( e : Dynamic ) {
            Context.error('Can\'t find HTN file ${path}', Context.currentPos());
			return null;
		}

        try {
			var ast = parse.parseFile(path,new haxe.io.BytesInput(content));
            generate(ast);
		} catch( msg : String ) {
            Context.error('Parse error ${msg}', Context.currentPos());
			return null;
		}

        return null;
    }
}
#end