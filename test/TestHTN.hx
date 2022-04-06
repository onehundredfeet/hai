package ;

import htn.Parser;

class TestHTN {
    public static function main() {
        var parse = new Parser();

        var file = "src/htn/example.htn";

        var content = try {
			sys.io.File.getBytes(file);
		} catch( e : Dynamic ) {
            trace('Error: ${e}');
			return;
		}

        try {
			var decls = parse.parseFile(file,new haxe.io.BytesInput(content));
		} catch( msg : String ) {
            trace ('Parse error: ' + msg);
			return;
		}

    }
}