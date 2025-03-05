package ai.sm.macro;
import grph.NodeGraph;
import haxe.macro.Expr;

typedef NodeGraphNode = grph.NodeGraph.Node;

typedef StateAction = {
	entries:Array<String>,
	exits:Array<String>,
	entrybys:Array<String>,
	entryfroms:Array<String>
}

typedef FieldTransition = {
	field:Field,
	transition:String
}

typedef ActionMaps = {
	entry:Map<String, Array<Field>>,
	traverse:Map<String, Array<Field>>,
	entryBy:Map<String, Array<FieldTransition>>,
	entryFrom:Map<String, Array<FieldTransition>>,
	exit:Map<String, Array<Field>>,
	globalEntry:Array<Field>,
	globalExit:Array<Field>,
	whiles:Map<String, Array<Field>>
}