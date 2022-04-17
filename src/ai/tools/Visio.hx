package ai.tools;
import ai.tools.*;
import ai.tools.StateXMLTools;

using Lambda;

class Visio {


    public static function read( path ) {
        var contents = sys.io.File.getContent(path);
        var root = Xml.parse(contents).firstElement();

        var machines = [];

        for( p in getPages( root )) {
            machines.push(parseMachine( p ));
        }

        return machines;
    }


    /*
    public static bool HasProp(this IElement e, string propName) {
        if (e == null) return false;

        return GetChildrenByTag(e, "Prop").Any( prop=> EqualsNoCase(GetChildByTag(prop, "Label").TextContent, propName));
    }


      public static IList<IElement> SelectTransitionShapes(IEnumerable<IElement> shapes) {
         return shapes.Where(x => x.IsTransitionShape()).ToArray();
     }

    */


    static function parseMachine( page : Xml ) {
        var shapes = getAllShapes(page);

        for(s in shapes) {
            //trace ("s: " + s.nodeName);
        }
        var sm = new StateMachineModel(
            page.get("NameU"),
            shapes,
            shapes.filter(isStateShape),
            getAllConnections(page),
            shapes.filter(isTransitionShape)
        );



        /*
        _name = page.GetAttribute("NameU");
        var _settings = Import.GetSettings(page);
        _shapes = Import.GetAllShapes(page);
        _stateShapes = Import.SelectStateShapes(_shapes);
        _connections = Import.GetConnections(page);
        _transitions = Import.SelectTransitionShapes(_shapes);

        _graph = Import.BuildGraph(_shapes, _connections);

        _defaultState = _stateShapes.FirstOrDefault(x => x.HasProp("default")).GetStateShapeName();
        if (_defaultState == null) {
            _defaultState = "DEFAULT";
        }

        if (_settings != null) {
            Reactive = _settings.HasProp("reactive");
            ReEntrant = _settings.HasProp("reentrant");
        }

        _stateNames = _stateShapes.Select(Import.GetStateShapeName).Where(x => x != null).Select(ParseUtil.ScrubLabel).Distinct().ToArray();
        _transitionNames = _transitions.Select(Import.GetTransitionShapeName).Where(x => x != null).Select(ParseUtil.ScrubLabel).Distinct().ToArray();
    }
        */
        return sm;
    }

    public static function getPages(root : Xml) : Array<Xml>{
        return getChildrenOf( root, "Pages");
    }

}