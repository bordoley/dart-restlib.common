part of restlib.common.collections;

class PersistentHashMap<K,V> extends Object with IterableMixin<Pair<K,V>> implements Dictionary<K,V> {
  static const PersistentHashMap EMPTY = const PersistentHashMap._internal(0, null);
  
  factory PersistentHashMap.fromMap(final Map<K,V> map) {
    PersistentHashMap<K,V> result = EMPTY;
    map.forEach((k,v) => result = result.put(k, v));
    return result;
  }
  
  factory PersistentHashMap.fromPairs(final Iterable<Pair<K,V>> pairs) {
    if (pairs is PersistentHashMap) {
      return pairs;
    } else if (pairs.isEmpty) {
      return EMPTY;
    } else { 
      return pairs.fold(EMPTY, 
          (PersistentHashMap<K,V> previousValue, Pair<K,V> element) 
            => previousValue.put(element.fst, element.snd));
    }
  }
  
  final int length;
  final _INode _root;
  
  const PersistentHashMap._internal (this.length, this._root);
  
  bool get isEmpty => length != 0;
  
  Iterator<Pair<K,V>> get iterator =>
      isNotNull(_root) ? _root.iterator : new List(0).iterator;
  
  Pair<K,V> get single =>
    (length == 1) ? (iterator..moveNext()..current) : throw new StateError("");
  
  Option<V> operator[](final K key){
    checkNotNull(key); 
    
    return isNotNull(_root) ? _root.find(0, key.hashCode, key) : Option.NONE;
  }
  
  bool contains(final Pair<K,V> pair) =>
    this[checkNotNull(pair).fst].map((value) => value == pair.snd).orElse(false);
  
  PersistentHashMap<K,V> put(final K key, final V value) {
    checkNotNull(key);
    checkNotNull(value);
    
    final _INode newroot = firstNotNull(_root, _BitmapIndexedNode.EMPTY).assoc(0, key, value);
    
    return (identical(newroot, _root)) ? this :
      new PersistentHashMap._internal(length + 1, newroot);
  }
  
  PersistentHashMap<K,V> remove(final K key) {
    checkNotNull(key);
    
    if (isNull(_root)) {
      return this;
    } else { 
      final _INode newroot = _root.without(0, key.hashCode, key);
      return identical(newroot, _root) ? this : new PersistentHashMap._internal(length - 1, newroot); 
    }
  }
}

abstract class _INode<K,V> extends Iterable<Pair<K,V>> {  
  _INode<K,V> assoc(int shift, int keyHash, K key, V value);
 
  Option<V> find(int shift, int keyHash, K key);
  
  _INode<K,V> without(int shift, int keyHash, K key);
}

class _ArrayNode<K,V> extends Object with IterableMixin<Pair<K,V>> implements _INode<K,V>{
  final int _count;
  final List<_INode> _array;
  
  _ArrayNode(this._count, this._array);
  
  Iterator<Pair<K,V>> get iterator =>
      _array
        .where((_INode e) => isNotNull(e))
        .expand((_INode e) => e)
        .iterator;

  _INode<K,V> assoc(final int shift, final int keyHash, final K key, final V value) { 
    final int idx = _mask(keyHash, shift);
    final _INode node = _array[idx];
    
    if (isNull(node)) {
      return new _ArrayNode(_count + 1, _cloneAndSetValue(_array, idx, _BitmapIndexedNode.EMPTY.assoc(shift + 5, keyHash, key, value)));   
    } else {
      final _INode n = node.assoc(shift + 5, keyHash, key, value);
      return identical(n, node) ? this : new _ArrayNode(_count, _cloneAndSetINode(_array, idx, n)); 
    }
  }
  
  Option<V> find(final int shift, final int keyHash, final K key){
    final int idx = _mask(keyHash, shift);
    final _INode node = _array[idx];
    return isNull(node) ? Option.NONE : node.find(shift + 5, keyHash, key); 
  }
  
  _INode<K,V> without(final int shift, final int keyHash, final K key){
    final int idx = _mask(keyHash, shift);
    final _INode<K,V> node = _array[idx];
    
    if (isNull(node)) {
      return this;
    }
    
    final _INode<K,V> n = node.without(keyHash, shift + 5, key);
    if (identical(n, node)) {
      return this;
    } else if (isNull(n)) {
      return (_count <= 8) ? // shrink  
          _pack(idx) : new _ArrayNode(_count - 1, _cloneAndSetINode(_array, idx, n));
    } else {
      return new _ArrayNode(_count, _cloneAndSetINode(_array, idx, n));
    }
  }
  
  _INode<K,V> _pack(final int idx) {
    final List newArray = new List(2*(_count - 1));
    int j = 1;
    int bitmap = 0;
    
    for (int i = 0; i < idx; i++) {
      if (isNotNull(_array[i])) {
        newArray[j] = _array[i];
        bitmap |= 1 << i;
        j += 2;
      }
    }
    
    for (int i = idx + 1; i < _array.length; i++) {
      if (isNotNull(_array[i])) {
        newArray[j] = _array[i];
        bitmap |= 1 << i;
        j += 2;
      }
    }
    
    return new _BitmapIndexedNode(bitmap, newArray);
  }
}

class _BitmapIndexedNode<K,V> extends Object with IterableMixin<Pair<K,V>> implements _INode<K,V> {
  static final _BitmapIndexedNode EMPTY = new _BitmapIndexedNode(0, new List(0));
  
  final int _bitmap;
  final List _array;
  
  _BitmapIndexedNode(this._bitmap, this._array);
  
  Iterator<Pair<K,V>> get iterator =>
      new _BitmapIndexedNodeIterator(this);
  
  _INode<K,V> assoc (final int shift, final int keyHash, final K key, final V value) { 
    final int hash = keyHash;
    final int bit = _bitpos(hash, shift);
    final int idx = _index(bit);
    
    if ((_bitmap & bit) != 0) {
      final K keyOrNull = _array[2*idx];
      final Object valOrNode = _array[2*idx+1];
      
      if (isNull(keyOrNull)) {
        final _INode n = (valOrNode as _INode).assoc(shift + 5, keyHash, key, value);
        return (n == valOrNode) ? this : 
          new _BitmapIndexedNode(_bitmap, _cloneAndSetINode(_array, 2*idx+1, n));
      } else if (key == keyOrNull) {
        return (value == valOrNode) ? this : 
          new _BitmapIndexedNode(_bitmap, _cloneAndSetValue(_array, 2*idx+1, value));
      } else {
        return new _BitmapIndexedNode(_bitmap, 
          _cloneAndSetKeyValue(_array, 
              2*idx, null, 
              2*idx+1, _createNode(shift + 5, keyOrNull.hashCode, keyOrNull, valOrNode, keyHash, key, value)));
      }
    } else {
      final int n = _bitCount32(_bitmap);
      
      if (n >= 16) {
        final List<_INode> nodes = new List(32);
        final int jdx = _mask(hash, shift);
        nodes[jdx] = EMPTY.assoc(shift + 5, keyHash, key, value);  
        
        int j = 0;
        for(int i = 0; i < 32; i++) {
          if(((_bitmap >> i) & 1) != 0) {
            if (isNull(_array[j])) {
              nodes[i] = _array[j+1];
            } else {
              nodes[i] = EMPTY.assoc(shift + 5, _array[j].hashCode, _array[j], _array[j+1]);
            }
            j += 2;
          }
        }
        
        return new _ArrayNode(n + 1, nodes);
      } else {
        List newArray = 
            new List(2*(n+1))..setAll(0, _array)
              ..[2*idx] = key
              ..[2*idx+1] = value
              ..setAll(2*(idx+1), _array.skip(2*idx));
        return new _BitmapIndexedNode(_bitmap | bit, newArray);
      }
    }
  }
  
  Option<V> find(final int shift, final int keyHash, final K key) {
    final int bit = _bitpos(key.hashCode, shift);
    if((_bitmap & bit) == 0) {
      return Option.NONE;
    }
    
    final int idx = _index(bit);
    final Object keyOrNull = _array[2*idx];
    final Object valOrNode = _array[2*idx+1];
    
    if(isNull(keyOrNull)) {
      return (valOrNode as _INode).find(shift + 5, keyHash, key);
    } else if(key == keyOrNull) {
      return new Option(valOrNode);
    } else {
      return Option.NONE;
    }
  }
  
  _INode<K,V> without(final int shift, final int keyHash, final K key) {
    final int bit = _bitpos(keyHash, shift);
    
    if((_bitmap & bit) == 0) {
      return this;
    }
    
    final int idx = _index(bit);
    final Object keyOrNull = _array[2*idx];
    final Object valOrNode = _array[2*idx+1];
    
    if(isNull(keyOrNull)) {
      _INode<K,V> n = (valOrNode as _INode).without(shift + 5, keyHash, key);
      if (n == valOrNode) {
        return this;
      } else if (isNotNull(n)) {
        return new _BitmapIndexedNode(_bitmap, _cloneAndSetINode(_array, 2*idx+1, n));
      } else if (_bitmap == bit) {
        return null;
      } else {
        return new _BitmapIndexedNode(_bitmap ^ bit, _removePair(_array, idx));
      }
    }
    
    if(key == keyOrNull) {
      // TODO: collapse
      return new _BitmapIndexedNode(_bitmap ^ bit, _removePair(_array, idx));
    }
    
    return this;
  }
  
  int _index(final int bit) =>
      _bitCount32(_bitmap & (bit - 1));
}

class _BitmapIndexedNodeIterator<K,V> implements Iterator<Pair<K,V>> {
  Pair<K,V> _current = null;
  int _currentIdx = -2;
  Iterator<Pair<K,V>> _nodeValueItr = null;
  final _BitmapIndexedNode _node;
    
  _BitmapIndexedNodeIterator(this._node);
  
  Pair<K,V> get current => _current;
  
  bool moveNext() {
    if (isNotNull(_nodeValueItr) && _nodeValueItr.moveNext()) {
        _current = _nodeValueItr.current;
        return true;
    } else {
      _nodeValueItr = null;
      _currentIdx += 2;
    }
    
    if (_currentIdx >= _node._array.length) {
      _current = null;
      _currentIdx = _node._array.length;
      return false;
    }
    
    var key = _node._array[_currentIdx];
    var value = _node._array[_currentIdx + 1];
    
    if (value is _INode) {
      _nodeValueItr = value.iterator;
      return moveNext();
    } else {
      _current = new Pair(key, value);
      return true;
    }
  }
}

class _HashCollisionNode<K,V> extends Object with IterableMixin<Pair<K,V>> implements _INode<K,V> {
  final int _hash;
  final int _count;
  final List _array;
  
  _HashCollisionNode(this._hash, this._count, this._array);
  
  Iterator<Pair<K,V>> get iterator =>  new _HashCollisionNodeIterator(this);
  
  _INode<K,V> assoc(final int shift, final int keyHash, final K key, final V value) {
    if (keyHash == _hash) {
      final int idx = findIndex(key);
      if (idx != -1) {
        return (_array[idx + 1] == value) ? this : new _HashCollisionNode(_hash, _count, _cloneAndSetValue(_array, idx + 1, value));
      } else {
        final List newArray = new List(_array.length + 2)..setAll(0, _array)..[_array.length] = key..[_array.length + 1] = value;
        return new _HashCollisionNode(_hash, _count + 1, newArray);
      }
    }
    // nest it in a bitmap node
    return new _BitmapIndexedNode(_bitpos(this._hash, shift), [null, this])
      .assoc(shift, keyHash, key, value);
  }
  
  Option<V> find(final int shift, final int keyHash, final K key) {
    final int idx = findIndex(key);
    if (idx < 0) {
      return Option.NONE;
    } else if (key == _array[idx]) {
      return new Option(_array[idx+1]);
    } else {
      return Option.NONE;
    }
  }
  
  int findIndex(final K key) {
    for (int i = 0; i < 2*_count; i+=2) {
      if (key == _array[i]) { return i; };
    }
    return -1;
  }
  
  _INode<K,V> without(final int shift, final int keyHash, final Object key){
    final int idx = findIndex(key);
    if(idx == -1) {
      return this;
    } else if (_count == 1) {
      return null;
    } else { 
      return new _HashCollisionNode(keyHash, _count - 1, _removePair(_array, idx~/2));
    }
  }
}

class _HashCollisionNodeIterator<K,V> implements Iterator<Pair<K,V>> {
  Pair<K,V> _current = null;
  int _nodeIdx = -2;
  final _HashCollisionNode _node;
  
  _HashCollisionNodeIterator(this._node);
  
  Pair<K,V> get current => _current;
  
  bool moveNext() {
    _nodeIdx += 2;
    
    if (_nodeIdx >= _node._array.length) {
      _nodeIdx = _node._array.length;
      _current = null;
      return false;
    }
    
    final K key = _node._array[_nodeIdx];
    final V value = _node._array[_nodeIdx +1];
    _current = new Pair (key, value);
    return true;
  }
}

List<_INode> _cloneAndSetINode(final List<_INode> array, final int i, final _INode a) =>
  array.toList(growable: false)..[i] = a;

List _cloneAndSetValue(final List array, final int i, final Object a) =>
  array.toList(growable: false)..[i] = a;

List _cloneAndSetKeyValue(final List array, final int i, final Object a, final int j, final Object b) =>
  array.toList(growable: false)..[i] = a..[j] = b;

_INode _createNode(final int shift, final int key1hash, 
                   final Object key1, final Object val1, 
                   final int key2hash, final Object key2, final Object val2) =>
  (key1hash == key2hash) ? 
      new _HashCollisionNode(key1hash, 2, [key1, val1, key2, val2]) :
        _BitmapIndexedNode.EMPTY
          .assoc(shift, key1hash, key1, val1)
          .assoc(shift, key2hash, key2, val2);
  


int _bitpos(final int hash, final int shift) =>
    1 << _mask(hash, shift);

// return ((hash << shift) >>> 27);// & 0x01f;
int _mask(final int hash, final int shift) =>
    (hash >> shift) & 0x01f;

// FIXME: 
int _bitCount32(int n) {
  int count = 0;
  while (n > 0) {
    count += n & 0x1;
    n = n >> 1;
   }
   return count;
}

List _removePair(final List array, int i) =>
  new List(array.length - 2)..setAll(0, array.take(2*i))..setAll(2*i, array.skip(2*(i+1)).take(array.length - 2 - 2*i));