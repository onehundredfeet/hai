package ai.bmn;

import ai.bmn.BMNAST;

class PrintAST {

    static function addIndent(buf : StringBuf, indent : Int) {
        for (i in 0...indent)
            buf.add('  ');
    }
    static function stateToString( buf : StringBuf, s : State, indent : Int) {
        addIndent(buf,indent);

        var stateTypeStr = switch(s) {
            case SSimple: "Simple";
            case SBehaviour(running, succeeded, failed): "Behaviour";
            case SParent(children): "Group";
        }

        buf.add('State [${stateTypeStr}]\n');
        switch(s) {
            case SBehaviour(running, succeeded, failed): 
                nodeToString(buf, running, indent + 1);
            case SParent(children): 
                for(c in children) {
                    stateToString(buf, c, indent + 1);
                }
            default:
        }
    }

    static function behaviourToString( buf : StringBuf, b : Behaviour, indent : Int) {
        addIndent(buf,indent);

        var bTypeStr = switch(b) {
            case BAbstract(methods):"Abstract";
            case BSequence(actions):"Sequence";
            case BAll(actions):"All";
            case BFirst(methods):"First";
            case BAction:"Action";
        }

        buf.add('Behaviour [${bTypeStr}]\n');

        switch(b) {
            case BAbstract(methods), BFirst(methods):
                for(m in methods) 
                    nodeToString(buf, m, indent + 1);
            case BSequence(actions), BAll(actions):
                for(a in actions) 
                    nodeToString(buf, a, indent + 1);
            default:
        }
    }

    static function nodeToString( buf : StringBuf, n : Node, indent : Int ) {
        addIndent(buf, indent);
        buf.add('Node ${n.name}\n');
        if (n.state != null) {
            stateToString(buf, n.state, indent + 1);
           
        }
        if (n.behaviour != null) {
            behaviourToString(buf, n.behaviour, indent + 1);
        }
    }

    public static function treeToString( t : Tree ) : String {
        var buf = new StringBuf();
        for (d in t.declarations) {
            buf.add('Declaration ${d.name}: ');

            switch(d.kind) {
                case DStateMachine(root): buf.add('State Machine \n'); nodeToString(buf, root, 1);
                case DBehaviourTree(root): buf.add('Behaviour Tree\n'); nodeToString(buf, root, 1);
                case DVariable(kind , name , type, value):buf.add('Variable\n');
                case DAction: buf.add('Action\n');
                case DParameter: buf.add('Parameter\n');
            }

           
        }

        return buf.toString();
    }
}