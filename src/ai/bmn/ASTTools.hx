package ai.bmn;
import gdoc.NodeGraphReader;
import gdoc.NodeDocReader;
import gdoc.NodeDoc;
import gdoc.NodeGraph;
import ai.bmn.BMNAST;
import haxe.ds.StringMap;
import ai.bmn.ASTTools;
using StringTools;
using Lambda;

class ASTTools {
static function walkNodesTopDownState( s : State, f : (Node)->Void) {
    switch(s) {
        case SBehaviour(running, succeeded, failed):
            walkNodesTopDown(running, f);
        case SParent(children):
            for(c in children) {
                walkNodesTopDownState(c, f);
            }
        default:
    }    
}

public static function walkNodesTopDown(node : Node, f : (Node)->Void) {
    f(node);
    
    if (node.behaviour != null) {
        switch(node.behaviour) {
            case BAbstract(methods),BFirst(methods):
                for (m in methods)
                    walkNodesTopDown(m, f);
            case BSequence(actions), BAll(actions):
                for (a in actions)
                    walkNodesTopDown(a, f);
            default:
        }    
    }

    if (node.state != null) {
        walkNodesTopDownState(node.state, f);
    }
}


static function walkNodesDepthFirstState( s : State, f : (Node)->Void) {
    switch(s) {
        case SBehaviour(running, succeeded, failed):
            walkNodesDepthFirst(running, f);
        case SParent(children):
            for(c in children) {
                walkNodesDepthFirstState(c, f);
            }
        default:
    }    
}

public static function walkNodesDepthFirst(node : Node, f : (Node)->Void) {
    
    if (node.behaviour != null) {
        switch(node.behaviour) {
            case BAbstract(methods),BFirst(methods):
                for (m in methods)
                    walkNodesDepthFirst(m, f);
            case BSequence(actions), BAll(actions):
                for (a in actions)
                    walkNodesDepthFirst(a, f);
            default:
        }    
    }

    if (node.state != null) {
        walkNodesDepthFirstState(node.state, f);
    }

    f(node);
}
}