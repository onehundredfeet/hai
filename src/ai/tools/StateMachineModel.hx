package ai.tools;
import ai.tools.StateXMLTools;
import ai.tools.GraphModel;
import tink.core.Pair;
using Lambda;

class StateMachineModel {


    public function new( n : String, shapes : Array<Xml>, states : Array<Xml>, connections : Array<Xml>, transitions : Array<Xml>) {
        _name = n;
        _allShapes = shapes;
        _stateShapes = states;
        _connections = connections;
        _transitions = transitions;

        _defaultStates = states.filter( function (x) return hasProp(x, "default") ).map(x -> getStateShapeName(x));


        if (_defaultStates == null || _defaultStates.length == 0) {
            _defaultStates.push("DEFAULT");
        }

        var filteredShapes = _stateShapes.filter( (x) -> getStateShapeName(x) != null);
        for (fs in filteredShapes) {
            _stateMap[scrubLabel(getStateShapeName(fs))] = fs;
        }
        _stateNames = [for (k in _stateMap.keys()) k];
        _transitionNames = unique(_transitions.map(getTransitionShapeName).filter(notNull).map(scrubLabel).array());

        buildGraph();
    }

    public var stateShapes(get, never):Array<Xml>;
    function get_stateShapes() :Array<Xml> return _stateShapes;

    public var name(get, never):String;
    function get_name() :String return _name;

    public var stateNames(get, never):Array<String>;
    function get_stateNames() :Array<String> return _stateNames;

    public var transitionNames(get, never):Array<String>;
    function get_transitionNames() :Array<String> return _transitionNames;

    public var transitions(get, never):Array<Xml>;
    function get_transitions() :Array<Xml> return _transitions;


    public var graph(get, never):GraphModel;
    function get_graph() :GraphModel return _graph;

    public var defaultStates(get, never):Array<String>;
    function get_defaultStates() :Array<String> return _defaultStates;

    public function defaultState(subgraph : Int):String {
        return _defaultStates[subgraph];
    }

    public function getStateNode( name : String ) {
        return _stateMap.get(name);
    }
    var _allShapes : Array<Xml>;
    var  _stateShapes : Array<Xml>;
    var _connections : Array<Xml>;
    var _transitions : Array<Xml>;
    
    var  _stateNames : Array<String>;
    var  _defaultStates : Array<String>;
    var _transitionNames : Array<String>;
    var  _name : String;

    var _stateMap = new Map<String, Xml>();
    var  _graph : GraphModel;


    function buildGraph() {
        _graph = new GraphModel();
   
        for ( shape in _allShapes) {
            var id = getShapeID(shape);
            if (isNotEmpty(id)) {
                _graph.IDToShape[id] = shape;
                _graph.ShapeToID[shape] = id;
            } else {
                trace('No id for ${shape}');
            }
        }

  
        for ( con in _connections) {
            var from = con.get("FromSheet");
            var source = con.get("FromPart") == "9";
            var to = con.get("ToSheet");
            if (isNotEmpty(from) && isNotEmpty(to)) {
                _graph.RawConnections[GraphModel.connectionId(from,source)] = to;
                if (source) {
                    var list = _graph.OutgoingConnections.get(to);
                    if (list == null) {
                        (_graph.OutgoingConnections[to] = new Array<String>()).push(from);
                    } else {
                        list.push(from);
                    }
                }
            } else {
                trace('Broken Connection ${from} ${to} ${source}');
            }
        }      
        
        for(i in _graph.OutgoingConnections.keyValueIterator()) {
            //trace('Connection: ${i.key} -> ${i.value}');
        }
    }
}