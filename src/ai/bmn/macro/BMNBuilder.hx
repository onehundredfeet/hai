package ai.bmn.macro;

#if macro
import haxe.macro.Expr;
import ai.bt.Parser;
import haxe.macro.Context;
import ai.tools.AST;
import ai.macro.MacroTools;
import ai.common.TaskResult;

using tink.MacroApi;
using haxe.macro.MacroStringTools;
using StringTools;
using Lambda;

import ai.macro.MacroTools;
import gdoc.NodeGraphReader;
import gdoc.NodeDocReader;
import gdoc.NodeDoc;
import gdoc.NodeGraph;
import ai.bmn.BMNAST;

class BMNBuilder {

    

    static function generate(graph : NodeGraph, root : NodeGraphNode, debug : Bool) {
        var cb = new tink.macro.ClassBuilder();

        var ast = ASTBuilder.buildAST(graph, root);


        trace('AST: ');
        trace(PrintAST.treeToString(ast));

        return cb.export(debug);
    }

    public static function build(path:String, page:String, debug = false):Array<Field> {

		var doc = NodeDocReader.loadPath(path);
        if (doc != null) {
            var graph = NodeGraphReader.fromDoc(doc, page);
            if (graph != null) {
                Context.registerModuleDependency(Context.getLocalModule(), path);

                var roots = graph.nodes.filter(
                    (x) -> {
                        if (x.parent != null) return false;
                        return x.properties.exists('root');
                    }
                );

                if (roots.length != 1) {
                    Context.fatalError('Most be exactly one root node in  ${page} from doc ${path}', Context.currentPos());
                    return null;
                }
                var root = roots[0];

                trace('Root ${root.name}');

                return generate(graph, root, debug);
            } else {
                Context.fatalError('Could not load page ${page} from doc ${path}', Context.currentPos());
            }
        } else {
            Context.fatalError('Could not load node doc ${path}', Context.currentPos());
        }

		return null;
    }

}

#end