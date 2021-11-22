package sm.tools;

class XmlDescendentIterator  {
    var _nodes : Array<Xml>;

    public function new(r : Xml) {
        _nodes = [for (n in r.elements())n];
    }
  
    public function hasNext() {
        return _nodes.length > 0;
    }
  
    public function next() {
        var n = _nodes.pop();

        for( c in n.elements()) {
            _nodes.push(c);
        }

        return n;
    }

    public function iterator() : Iterator<Xml> {
        return this;
    }
  }
  
