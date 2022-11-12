package ai.tools;

import sys.io.File;
import haxe.Json;
import tink.core.Pair;
import ai.tools.StateMachineModel;
import ai.tools.Visio;
import ai.tools.StateXMLTools;
import ai.macro.MacroTools;
import haxe.ds.StringMap;

using StringTools;

class VisioToJSON {

    static function getPath( n : Xml) : String {
        if (isGroupProxy(n)) {
            n = getParentGroup(n);
        }

        var p = n.parent;
        var i = 0;
        var base = getParentGroup(n) != null ? getPath(getParentGroup(n)) : "";

        for (x in p.iterator()) {
            if (x == n) {
                return base + "|" + i;
            }
            i++;
        }

        throw "Node not found in parent";
    }
	public static function main() {
		var args = Sys.args();

		var smArray = Visio.read(args[0]);

		var pages = [];

		for (m in smArray) {
			var page = new StringMap<Dynamic>();
			trace('Found model ${m.name}');

			var nodes = [];
            var stateIDs = new haxe.ds.StringMap<Int>();
            var stateIDCount = 0;
            for (s in m.stateShapes) {
                if (isGroupProxy(s)) {
					s = getParentGroup(s);
				}
                stateIDs.set(getPath(s),stateIDCount++);
            }

			for (s in m.stateShapes) {
				var node = new StringMap<Dynamic>();
				node.set("name", getRawStateShapeName(s));
				if (isGroupProxy(s)) {
					s = getParentGroup(s);
				}

                node.set("id", stateIDs.get(getPath(s)));
                
				var p = getRawStateShapeName(getParentGroup(s));
				if (p != null)
					node.set("parent", p);
                if (isGroupNode(s)) {
                    var children = [];
                    var shapes = getShapes(s);
                    for (c in shapes) {
                        if (!isGroupProxy(c)) {
                            children.push( getRawStateShapeName(c));
                        }
                    }
                    node.set("children", children);
                }


                var outgoing = [];
                m.graph.walkOutgoingConnections(s, x -> {}, (trigger, targetState) -> {
                    var connection = new StringMap<Dynamic>();
//					var sourceStateName = getStateShapeName(s);
                    connection.set("target", getStateShapeName(targetState ));
                    connection.set("name", trigger);
                    connection.set("id", stateIDs.get(getPath(targetState)));
                    var properties = getPropertyMap(s);
                    connection.set("properties", properties);
                
                    outgoing.push(connection);
                }, false);
                if (outgoing.length > 0) {
                    node.set('outgoing', outgoing);
                }
                
                var properties = getPropertyMap(s);
                node.set("properties", properties);
				nodes.push(node);
			}
			
            
			page.set('nodes', nodes);
			page.set('name', m.name);
			pages.push(page);
		}

		File.saveContent("out.json", Json.stringify(pages, null, "\t"));
	}
}
