part of restlib.common.collections;

abstract class PersistentCollection<E> extends Iterable<E> {
  PersistentCollection<E> add(E value);
  
  PersistentCollection<E> addAll(Iterable<E> elements);  
  
  bool remove(E element);
}