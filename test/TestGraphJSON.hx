import ai.tools.NodeGraphReader;
import sys.io.File;
import gdoc.NodeGraph;
import gdoc.NodeDoc;
import gdoc.NodeGraphReader;

class TestGraphJSON {

    static function dumpGraph( graph : NodeGraph) {
        trace('Nodes');
        for (n in graph.nodes) {
            trace("\t" + n.name);
            for (p in n.properties.keyValueIterator()) {
                trace('\t\t${p.key}:${p.value}');
            }
            for (c in n.outgoing) {
                trace('\t\tconnects to ${c.target.name} by ${c.name}');
            }
            for (c in n.incoming) {
                trace('\t\tconnects from ${c.source.name} by ${c.name}');
            }
        }
    }

    public static function main() {
        var doc = loadNodeDoc("out.json");
        var cowbt = NodeGraphReader.fromDoc(doc, "cowbt");
        var cowbrain = NodeGraphReader.fromDoc(doc, "cowbrain");

        trace('Behaviour tree');
        dumpGraph(cowbt);

        trace('Behaviour brain');
        dumpGraph(cowbrain);
       
    }
}