package ai.tools;

#if false 

import ai.tools.NodeGraph;
import ai.tools.NodeDoc;
import haxe.ds.IntMap;

class NodeGraphReader {

    public static function fromDoc( doc : NodeDoc, pageName : String ) : NodeGraph {
        for (page in doc) {
            if (page.name.toLowerCase() == pageName.toLowerCase()) {
                var g = new NodeGraph();
                var nodeMap = new IntMap<NodeGraphNode>();

                for (doc_n in page.nodes) {
                    var graph_n = g.addNode();
                    graph_n.name = doc_n.name;
                
                    for (prop in doc_n.properties.keyValueIterator()) {
                        graph_n.properties.set(prop.key, prop.value);
                    }

                    nodeMap.set(doc_n.id, graph_n);
                }
                for (doc_n in page.nodes) {
                    var graph_n = nodeMap.get(doc_n.id);

                    if (doc_n.parentID != null) {
                        var parent_n = nodeMap.get(doc_n.parentID);
                        var pc = new  NodeGraphArc();
                        pc.source = parent_n;
                        pc.target = graph_n;
                        pc.name = "_CHILD";
                        parent_n.outgoing.push(pc);
                        graph_n.incoming.push(pc);
                    }

                    if (doc_n.outgoing != null) {
                        for (doc_c in doc_n.outgoing) {
                            var c = new NodeGraphArc();
                            c.source = graph_n;
                            c.target = nodeMap.get(doc_c.id);
                            c.name = doc_c.name;
    
                            graph_n.outgoing.push(c);
                            c.target.incoming.push(c);
    
                            for (prop in doc_c.properties.keyValueIterator()) {
                                c.properties.set(prop.key, prop.value);
                            }
                        }
                    }

                }


        
                return g;
            }
        }

        return null;
    }
}
#end