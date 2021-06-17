/*
 * Copyright (c) 2012, 2020, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 *
 */

template<
    typename IMPL,
    typename K, typename V,
    unsigned (*HASH)  (K const&),
    bool     (*EQUALS)(K const&, K const&)>
class ResourceHashtableXBase {
 protected:

  class Node {
   public:
    unsigned _hash;
    K _key;
    V _value;
    Node* _next;

    Node(unsigned hash, K const& key, V const& value) :
        _hash(hash), _key(key), _value(value), _next(NULL) {}

    // Create a node with a default-constructed value.
    Node(unsigned hash, K const& key) :
        _hash(hash), _key(key), _value(), _next(NULL) {}

  };

  // Returns a pointer to where the node where the value would reside if
  // it's in the table.
  Node** lookup_node(unsigned hash, K const& key) {
    unsigned index = hash % size();
    Node** ptr = &_table[index];
    while (*ptr != NULL) {
      Node* node = *ptr;
      if (node->_hash == hash && EQUALS(key, node->_key)) {
        break;
      }
      ptr = &(node->_next);
    }
    return ptr;
  }

  Node const** lookup_node(unsigned hash, K const& key) const {
    return const_cast<Node const**>(
        const_cast<ResourceHashtableXBase*>(this)->lookup_node(hash, key));
  }

  Node** _table;

  unsigned size() { return ((IMPL*)this)->size_impl(); }

 public:
  ResourceHashtableXBase(unsigned the_size) {
    // Don't call size() yet as IMPL::_size is not initialized yet
    _table = new Node*[the_size];
  }

  bool contains(K const& key) const {
    return get(key) != NULL;
  }

  V* get(K const& key) const {
    unsigned hv = HASH(key);
    Node const** ptr = lookup_node(hv, key);
    if (*ptr != NULL) {
      return const_cast<V*>(&(*ptr)->_value);
    } else {
      return NULL;
    }
  }

 /**
  * Inserts or replaces a value in the table.
  * @return: true:  if a new item is added
  *          false: if the item already existed and the value is updated
  */
  bool put(K const& key, V const& value) {
    unsigned hv = HASH(key);
    Node** ptr = lookup_node(hv, key);
    if (*ptr != NULL) {
      (*ptr)->_value = value;
      return false;
    } else {
      *ptr = new Node(hv, key, value);
      return true;
    }
  }
};


template<
    typename K, typename V,
    unsigned SIZE = 256,
    unsigned (*HASH)  (K const&)           = primitive_hash<K>,
    bool     (*EQUALS)(K const&, K const&) = primitive_equals<K>>
class ResourceHashtableXConst : public ResourceHashtableXBase<ResourceHashtableXConst<K, V, SIZE, HASH, EQUALS>, K, V, HASH, EQUALS> {
public:
  unsigned size_impl() { return SIZE; }

  ResourceHashtableXConst() : ResourceHashtableXBase<ResourceHashtableXConst, K, V, HASH, EQUALS>(SIZE) {}
};

template<
    typename K, typename V,
    unsigned (*HASH)  (K const&)           = primitive_hash<K>,
    bool     (*EQUALS)(K const&, K const&) = primitive_equals<K>>
class ResourceHashtableXVar : public ResourceHashtableXBase<ResourceHashtableXVar<K, V, HASH, EQUALS>, K, V, HASH, EQUALS> {
  unsigned _size;
public:
  unsigned size_impl() { return _size; }
  ResourceHashtableXVar(unsigned size) : ResourceHashtableXBase<ResourceHashtableXVar, K, V, HASH, EQUALS>(size), _size(size) {}
};

