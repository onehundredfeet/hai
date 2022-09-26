package ai.tools;

import haxe.ds.Map;
using Lambda;
using hx.strings.Strings; // augment all Strings with new functions

function isGroupNode(shape : Xml) : Bool{
    if (shape == null) return false;
    return shape.get("Type") == "Group";
}

function isStateShape(e : Xml) : Bool{
    if (e == null) return false;
    if (isGroupNode(e)) return false;

    var misc = getChild(e, "Misc");
    var v = getChildValue(misc, "ObjType");

 //   trace("Trying " + e.nodeName + "," + misc.nodeName + "," + v);
    return v == "1";
}

function getElementValue( e : Xml) : String{
    for(cc in e) {
        if (cc.nodeType == PCData || cc.nodeType == CData) {
            return cc.nodeValue;
        }
        //trace("NT: " + cc.nodeType);
    }
    //return e.nodeValue;
    return null;
}
function getChildValue( e : Xml, childName : String) : String {
    if (e == null) return null;
    for( c in e.elementsNamed(childName) )  {
        //trace("Trying2:" + c.nodeName);
        return getElementValue(c);
    }
    return null;
}

function getChild( e : Xml, childName : String) {
    if (e == null) return null;
    for( c in e.elementsNamed(childName) )  {
        return c;
    }
    return null;
}

function unique(a : Array<String>) {
    var m = new std.Map<String, Bool>();
    for(v in a) {
        m.set(v, true);
    }
    return [for (k in m.keys()) k ];
}

function strEqNoCase( a : String, b : String) {
    if (a == null && b == null) return true;
    if (a == null) return false;
    if (b == null) return false;

    if (a.length != b.length) return false;

    for (i in 0...a.length) {
       if (a.charAt(i) != b.charAt(i)) {
           return a.toUpperCase() == b.toUpperCase();
       }

    }
    return true;
}
function hasProp( e : Xml, propName : String) : Bool{
    if (e == null) return false;
    for( c in e.elementsNamed("Prop") ) {
        if (strEqNoCase(getChildValue(c, "Label"),propName)) {
            return true;
        }

    }
    return false;
}

function getPropValue( e : Xml, propName : String) : String{
    if (e == null) return null;
    for( c in e.elementsNamed("Prop") ) {
        if (strEqNoCase(getChildValue(c, "Label"), propName)) {
            return getChildValue(c, "Value");
        }

    }
    return null;
}

function isIgnored( e : Xml) : Bool {
    if (e == null) return false;
    return hasProp(e, "Ignore");
}

function getAllShapes( page : Xml) {
    var s = page.elementsNamed("Shapes").next();
    var i = new XmlDescendentIterator( s ).filter(function( x ) return (x.nodeName == "Shape" && !isIgnored(x))) ;
    return i.array();
}

function firstChild(e : Xml, named:String) {
    for( c in e.elements()) {
        if(c.nodeName == named) return c;
    }
    return null;
}

function getChildrenOf(parent : Xml, named:String) : Array<Xml> {
    var shapes = firstChild(parent, named);

    if (shapes != null) {
        return [for (s in shapes.elements()) s];
    }
    return [];
}

function getAllConnections( page : Xml ) {
    return [ for (c in getChild(page, "Connects").elements()) c];
}

function isTransitionShape( e : Xml ) : Bool {
    if (e == null) return false;
    return !isGroupNode(e) && getChildValue(getChild(e, "Misc"), "ObjType") == "2";
}

function selectTransitionShapes(shapes : Array<Xml>) {
    return shapes.filter( isTransitionShape );
}

function isEmpty( s : String ) {
    if (s == null) return true;
    if (s.length == 0) return true;

    for(i in 0...s.length) {

    }

    return false;
}

function isNotEmpty( s : String ) {
    return !isEmpty(s);
}

function getShapeID(shape : Xml) {
    return shape.get("ID");
}

function first<T>( a : Array<T>, ?d : T) : T{
    if (a == null) return d;
    if (a.length == 0) return d;

    return a[0];
}

function scrubLabel( label : String) {
    if (label == null) return "";
    
    var trimmed = StringTools.trim(label );
    var s = StringTools.replace(trimmed, " ", "_");
    s = StringTools.replace(s, "\n", "_");
    s = StringTools.replace(s, "-", "_");
    return s.toUpperCase();
}

function getShapes(parent: Xml) {
    return getChildrenOf(parent, "Shapes");
}

function getGroupProxy(group : Xml) {
    return first(getShapes(group));
}

function getNameEnumName( nodeName : String )  {
    return "S_" + scrubLabel( nodeName);
}

function getGroupName(group : Xml) : String{
    return getStateShapeName(getGroupProxy(group));
}



function getShapeContent(shape : Xml) : String{
    var x= getChildValue(shape, "Text");
    if (x == null) return "";
    return x;
}


function getRawStateShapeName(shape : Xml) : String{
    if (shape == null) return null;

    var name = "";
    
    if (isGroupNode(shape)) {
        name = getGroupName(shape);
    }
    else {
        name = getShapeContent(shape);
    }

    return name;
}

function getStateShapeName(shape : Xml) : String{
    if (shape == null) return null;

    var name = getRawStateShapeName(shape);
    
    return scrubLabel(name);
}

function notNull<T>(shape : T ) : Bool {
    if (shape == null) return false;
    return true;
}
function getTransitionShapeName(shape : Xml) : String{
    if (shape == null) return "";
    return getShapeContent(shape).toUpperCase();
}

function getParentGroup(shape : Xml) : Xml {
    if (shape == null) return null;
    if (shape.parent == null) return null;

    var parent = shape.parent.parent;

    //trace('parent is ${parent.get("Name")}');
    if (parent != null && parent.nodeName == "Shape") {
        return parent;
    }
    return null;
}

function getRootNode(shape : Xml) {
    if (shape == null) return shape;
    if (shape.parent == null) return shape;

    var parent = shape.parent.parent;

    if (parent != null && parent.nodeName == "Shape") {
        return getRootNode(parent);
    }
    return shape;
}

function isGroupProxy(shape : Xml) : Bool {
     return getStateShapeName(getParentGroup(shape)) == getStateShapeName(shape);
 }

 function getConcreteShape(current: Xml) : Xml{
     if (current == null) return null;

    if (isGroupNode(current)) {
        return getGroupProxy(current);
    }

    return current;
}
function getGroupInitialStateName(group : Xml) : String{
    return getStateShapeName(getGroupInitialState(group));
}
function getInitialLeaf(shape: Xml)  : Xml{
    if (isGroupProxy(shape)) shape = getParentGroup(shape);

    if (!isGroupNode(shape)) return shape;

    return getInitialLeaf(getGroupInitialState(shape));
}

function getGroupInitialState(group : Xml) : Xml{
    if (isGroupProxy(group)) group = getParentGroup(group);
    var  shapes : Array<Xml> =  getShapes(group);
    if (shapes == null) throw "Group " + getGroupName(group) + " has no child states";

    var initialState = first(shapes.filter( x -> hasProp(x,"initial") && !isGroupProxy(x) ));

    if (initialState == null){
//        trace(shapes);
        throw "Group " + getGroupName(group) + " has no initial state";
    } 

    return initialState;
}

function isAncestorOf( shape : Xml, otherShape : Xml) : Bool {
    if (shape == otherShape) return true;

    while (otherShape.parent != null) {
        if (shape == otherShape.parent) return true;
        otherShape = otherShape.parent;
    }
    return false;
}

function firstCommonAncestor(shape : Xml, otherShape : Xml) {
    if (shape == otherShape) return shape;
    if (isAncestorOf(shape, otherShape)) return shape;
    if (isAncestorOf(otherShape, shape)) return otherShape;
    
    var parent : Xml = null;

    while ((parent = getParentGroup(shape)) != null) {
        if (isAncestorOf(parent, otherShape)) 
            return parent;
        shape = parent;
    }

    return null;
}