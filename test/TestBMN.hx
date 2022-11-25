package ;
import ai.common.TaskResult;

@:build( ai.bmn.macro.BMNBuilder.build( "test/example_bmn.vdx", "bmn1", true))
class LocalExampleBMN {
    public function new() {

    }

}


class TestBMN {


    public static function main() {
        var x = new LocalExampleBMN();

//        x.DASH_RANGE = 30.;
  //      x.enemyRange = 45.;
    //    var y = x.btTick();

     //   trace('Result = ${y}');
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