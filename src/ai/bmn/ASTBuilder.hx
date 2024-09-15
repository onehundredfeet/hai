package ai.bmn;

import gdoc.NodeGraphReader;
import gdoc.NodeDocReader;
import gdoc.NodeDoc;
import gdoc.NodeGraph;
import ai.bmn.BMNAST;
import haxe.ds.StringMap;
import ai.bmn.ASTTools;

typedef NodeGraphNode = gdoc.Node;

using StringTools;
using Lambda;

class ASTBuilder {
	static function getThenChain(a:NodeGraphArc):Array<NodeGraphArc> {
		var x = a.target.outgoing.find((x) -> x.name.startsWith('THEN'));

		if (x == null) {
			return [a];
		}

		var y = getThenChain(x);
		y.unshift(a);
		return y;
	}

	static function getConnectedNode(a:NodeGraphArc):Node {
		var x = getBehaviourAST(a.target);
		return x;
	}

	static function getBehaviour(n:NodeGraphNode):Behaviour {
		var named_connections = n.outgoing.filter((x) -> {
			if (x.name.length == 0) {
				return false;
			}
			if (x.name == "_CHILD")
				return false;

			return true;
		});

		if (named_connections.length == 0) {
			return BAction;
		}

		//  DAction(name : String, async : Bool, condition : BooleanExpression, effects : Array<Effect>,parameters:Array<Parameter>,calls:Array<Call>);

		var dos = named_connections.filter((x) -> x.name.startsWith('DO'));
		var trys = named_connections.filter((x) -> x.name.startsWith('TRY'));
		if (dos.length > 0 && trys.length > 0) {
			throw("Can not mix dos and trys on the same node");
		}

		if (dos.length > 0) {
			if (dos.length > 1) {
				return BAll(dos.map(getConnectedNode));
			} else {
				return BSequence(getThenChain(dos[0]).map(getConnectedNode));
			}
		}
		if (trys.length > 0) {
			if (trys.length > 1) {
				return BFirst(trys.map(getConnectedNode));
			} else {
				return BAbstract(getThenChain(trys[0]).map(getConnectedNode));
			}
		}

		return BAction;
	}

	static function getBehaviourAST(n:NodeGraphNode):Node {
		var childCount = n.numChildren();
		var state = null;
		if (childCount > 0) {
			trace('Behaviour tree has state');
			state = getState(n);
		}
		return {name: n.name, state: state, behaviour: getBehaviour(n)};
	}

	static function conformsToTreeNode(x:NodeGraphNode) {
		if (x.numChildren() == 3 && x.hasChild("RUNNING") && x.hasChild("SUCCEEDED") && x.hasChild("FAILED")) {
			return true;
		}
		return false;
	}

	static function getState(x:NodeGraphNode):State {
		var childStates = x.getChildren();
		var isParent = childStates.length > 0;
		if (conformsToTreeNode(x)) {
			var rn = x.getChild('RUNNING');
			var sn = x.getChild('SUCCEEDED');
			var fn = x.getChild('FAILED');

			return SBehaviour(getStateAST(rn), getState(sn), getState(fn));
		}

		var children = [];
		for (c in childStates) {
			children.push(getState(c));
		}

		if (children.length > 0) {
			return SParent(children);
		}
		return SSimple;
	}

	static function getStateAST(x:NodeGraphNode):Node {
		var externalConnections = x.getNonChildren();

		var behaviour = null;
		if (externalConnections.length > 0) {
			behaviour = getBehaviour(x);
		}

		return {name: x.name, behaviour: behaviour, state: getState(x)};
	}

	static function topNodeToAst(x:NodeGraphNode):Declaration {
		var dcl = x.properties.get('declare');
		return switch (dcl) {
			case 'tree': {name: x.name, kind: DBehaviourTree(getBehaviourAST(x))};
			case 'state': {name: x.name, kind: DStateMachine(getStateAST(x))};
			case 'variable': null;
			default: null;
		}
	}

	static function fixReferences(declarationMap:StringMap<Declaration>, node:Node) {
		ASTTools.walkNodesTopDown(node, (n) -> {
			if (n.behaviour != null) {
				switch (n.behaviour) {
					case BAction:
						if (declarationMap.exists(n.name)) {
							n.behaviour = BInstance(n.name);
						}
					default:
				}
			}
		});
	}

	static function propagateAbstract(declarationMap : StringMap<Declaration>, root:Node) {
		ASTTools.walkNodesDepthFirst(root, (n) -> {
			if (n.state == null && n.behaviour == null) {
				n.abstractBranch = false;
			} else if (n.behaviour != null) {
				switch (n.behaviour) {
					case BAbstract(methods), BFirst(methods): n.abstractBranch = true;
					case BSequence(actions), BAll(actions):
						for (a in actions) {
							if (a.abstractBranch != null && a.abstractBranch) {
								n.abstractBranch = true;
								break;
							}
						}
					case BInstance(name): n.abstractBranch = false;
					case BAction: n.abstractBranch = false;
				}
			} else {
				n.abstractBranch = false;
			}
		});
	}

	public static function buildAST(graph:NodeGraph, root:NodeGraphNode):Tree {
		// global declarations
		var declarations = graph.nodes.filter((x) -> {
			if (x.properties.exists('declare'))
				return true;
			//            if (x.properties.exists('root')) return true;
			return false;
		}).map(topNodeToAst).filter((x) -> x != null);

		var rootDcl:Declaration = declarations.find((x) -> x.name == root.name);

		var root = (rootDcl != null) ? switch (rootDcl.kind) {
			case DBehaviourTree(node): node;
			case DStateMachine(node): node;
			default: null;
		} : null;

		var declarationMap = new StringMap<Declaration>();
		for (d in declarations)
			declarationMap.set(d.name, d);

		// second pass
		for (d in declarations) {
			switch (d.kind) {
				case DStateMachine(root), DBehaviourTree(root):
					fixReferences(declarationMap, root);
					propagateAbstract(declarationMap, root);
				default:
			}
		}
		return {root: root, declarations: declarations};
	}
}
