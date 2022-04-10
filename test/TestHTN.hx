package ;

import htn.Parser;
import htn.ExampleHTN;
import htn.Operator;

@:build( htn.macro.HTNBuilder.build( "src/htn/example.htn"))
class LocalExampleHTN {
    public function new() {}

    @:tick(op1)
    function op1(parameter : Float) : OperatorResult {
        trace("Operator 1:");
        return OperatorResult.Running;
    }

    @:begin(op1)
    function op1_Begin() : OperatorResult {
        trace("Operator 1:");
        return OperatorResult.Running;
    }
}

class TestHTN {

    static function generate( ast : Array<Declaration> ) {
        for(d in ast) {
            trace('${d}');
        }
    }

    public static function main() {
        var x = new LocalExampleHTN();
        var y = new ExampleHTN();
        /*
        var parse = new Parser();
        var file = "src/htn/example.htn";

        var content = try {
			sys.io.File.getBytes(file);
		} catch( e : Dynamic ) {
            trace('Error: ${e}');
			return;
		}

        try {
			var ast = parse.parseFile(file,new haxe.io.BytesInput(content));
            generate(ast);
		} catch( msg : String ) {
            trace ('Parse error: ' + msg);
			return;
		}
*/
    }
}