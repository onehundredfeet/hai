package ai.tools;

import tink.core.Pair;
import ai.tools.StateXMLTools;
using Lambda;

class GraphModel {
	public function new() {}

	public var IDToShape = new Map<String, Xml>();
	public var ShapeToID = new Map<Xml, String>();
	public var RawConnections = new Map<String, String>();
	public var OutgoingConnections = new Map<String, Array<String>>();

    public static function connectionId(targetID : String,source:Bool) : String {
        return targetID + "_" + source;
    }

	public function walkOutgoingConnections(current:Xml, missingName:String->Void, validConnection:(String, Xml) -> Void, requireTransitionContent = true) {
		var stateShape = getConcreteShape(current);
        
		var id = scrubLabel(getShapeID(stateShape));

        
		if (isEmpty(id))
			return;
        //trace('Walking ${id} [${OutgoingConnections[id]}]w/${OutgoingConnections}' );

        var targetIDs = OutgoingConnections[id];
		if (targetIDs != null) {
          //  trace("Connections " + targetIDs);

			for (targetID in targetIDs) {
                var targetNode = IDToShape[targetID];
                //trace('walking ${id} to ${targetID} : ${targetNode} on ${[for (k in IDToShape.keys()) k]}');

				if (targetNode != null) {
					if (isStateShape(targetNode)) {
						if (missingName != null)
							missingName(targetID);
					} else if (isTransitionShape(targetNode)) {
						var targetTransition = targetNode;
						var transitionContent = scrubLabel(getTransitionShapeName(targetTransition));
						if (requireTransitionContent && isEmpty(transitionContent)) {
							if (missingName != null)
								missingName(transitionContent);
						} else {
							var finalNodeID = RawConnections[connectionId(targetID,false)];
                            if (finalNodeID != null) {
                                if (validConnection != null) {
                                    validConnection(transitionContent, IDToShape[finalNodeID]);
                                }    
                            } else {
                                trace('No connection ${targetID} in ${[for (k in RawConnections.keys()) k]}');
                            }
						}
					}
				}
			}
		}
	}
	/*
		public IEnumerable<(Xml, Xml)> WalkOutgoingConnections(Xml current, Action<String> missingName) {
			
			var stateShape = current.GetConcreteShape();
			var id = stateShape.GetShapeID();
			if (String.IsNullOrWhiteSpace(id)) yield break;

			if (OutgoingConnections.TryGetValue(id, out var targetIDs)) {
				foreach (var targetID in targetIDs) {
					if (IDToShape.TryGetValue(targetID, out var targetNode)) {
						if (targetNode.IsStateShape()) {
							missingName?.Invoke(targetID);
						}
						else if (targetNode.IsTransitionShape()) {
							var targetTransition = targetNode;
							var transitionContent = targetTransition.GetTransitionShapeName();
							if (String.IsNullOrWhiteSpace(transitionContent)) {
								missingName?.Invoke(transitionContent);
							}
							else {
								var finalNodeID = RawConnections[(targetID, false)];

								var finalShape = IDToShape[finalNodeID];

								yield return (targetNode, finalShape);
								//.Permit( ETrigger.<#=transitionContent #>, EState.<#= finalNode #> )
							}
						}
					}
				}

			}
		}
	 */
}
