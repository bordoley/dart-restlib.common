part of restlib.common.collections;

abstract class ImmutableSetMultimap<K,V> extends IterableBase<Pair<K,V>> implements ImmutableMultimap<K,V,ImmutableSet<V>> {
  ImmutableDictionary<K, ImmutableSet<V>> get dictionary;
  
  ImmutableSetMultimap<K,V> insertAll(final Iterable<Pair<K, V>> other);
  
  ImmutableSetMultimap<K,V> insert(final K key, final V value);
  
  ImmutableSetMultimap<K,V> removeAt(final K key);
}
