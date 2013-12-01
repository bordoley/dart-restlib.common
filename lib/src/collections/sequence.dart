part of restlib.common.collections;

class _SequenceIterator<E> implements Iterator<E> {
  final Sequence<E> _list;
  int _currIndex = -1;
  
  _SequenceIterator(this._list);
  
  E get current => 
      (_currIndex < 0 || _currIndex >= _list.length) ?
          null : _list[_currIndex].value;

  bool moveNext() =>
      (++_currIndex) < _list.length; 
}

class _ReverseSequence<E> extends _AbstractSequence<E> { 
  final Sequence<E> reversed;
  
  _ReverseSequence(this.reversed);
  
  int get length =>
      reversed.length;
  
  Option<E> operator[](final int index) =>
      reversed[reversed.length - index - 1];
  
  bool containsKey(final int key) =>
      (reversed.length - key) >= 0;
}

class _SubSequence<E> extends _AbstractSequence<E> { 
  final Sequence<E> _delegate;
  final int _start;
  final int length;
  
  _SubSequence(this._delegate, this._start, this.length) {
    checkArgument(_start + length <= _delegate.length);
  }
  
  Option<E> operator[](final int index) =>
      _delegate[_start + index];
  
  bool containsKey(final int key) =>
      (_start + key) < length;
}

abstract class _AbstractSequence<E> extends IterableBase<E> implements Sequence<E> {
  Iterator<E> get iterator =>
      new _SequenceIterator(this);
  
  Iterable<int> get keys =>
      new List.generate(length, 
          (final int index) => index);
  
  Iterable<E> get values =>
      this;
  
  Sequence<E> get reversed =>
      new _ReverseSequence(this);
  
  List<E> asList() =>
      new _SequenceAsList(this);
  
  bool containsValue(final E value) =>
      contains(value);
  
  int indexOf(E element, [int start=0]) {
    checkNotNull(element);
    for (int i = start; i < length; i++) {
      if (this[i] == element) {
        return i;
      }
    }
    return -1;
  }
  
  Sequence<E> subSequence(int start, int length) =>
      new _SubSequence(this, start, length);
}

class _SequenceAsList<E> 
    extends Object
    with ListMixin<E>
    implements List<E>, Forwarder {

  final Sequence<E> delegate;
  
  _SequenceAsList(this.delegate);
  
  E operator [](int index) =>
      delegate.elementAt(index);
  
  void operator []=(int index, E value) =>
      throw new UnsupportedError("List is readonly");
      
  int get length =>
      delegate.length;
  
  void set length(int length) =>
      throw new UnsupportedError("List is readonly");
}
  
  