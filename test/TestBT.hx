package ;
import ai.tools.AST;
import ai.common.TaskResult;

@:build( ai.bt.macro.BTBuilder.build( "test/example.bt", true))
class LocalExampleBT {
    public function new() {}
    @:tick(stepA)
    function stepA() : TaskResult {
        trace("stepA");
        return TaskResult.Completed;
    }

    /*
    

    @:tick(op2)
    function op2() : TaskResult {
        trace("Operator 2:");
        return TaskResult.Running;
    }

    @:tick(op3)
    function op3() : TaskResult {
        trace("Operator 3:");
        return TaskResult.Running;
    }

    @:begin(op1)
    function op1_Begin() {
        trace("Begin Operator 1:");
    }

    //Called by HTN source
    function testCall(x : Float) {
        trace ("Test Call");
    }
    */
}

class TestBT {

    static function generate( ast : Array<Declaration> ) {
        for(d in ast) {
            trace('${d}');
        }
    }

    public static function main() {
        var x = new LocalExampleBT();

        x.btTick();

        /*
        var y = new ExampleHTN();

        
        x.DASH_RANGE = 30.;
        x.enemyRange = 45;

        var bs = x.plan( LocalExampleHTN.A_ABSTRACT1  );
        trace('Planning resulted in ${bs}');
        x.execute();
        trace('Execution began');
        var res = x.tick();
        trace('Ticking resulted in ${res}');
        var res = x.tick();
        var res = x.tick();
        var res = x.tick();
        var res = x.tick();
        */
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