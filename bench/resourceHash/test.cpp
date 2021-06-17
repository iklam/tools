#include <stdlib.h>
#include <stdio.h>
#include <string.h>

typedef unsigned int           uintptr_t;
typedef long long              intx;
typedef unsigned long long     uintx;
#define UINT64_FORMAT          "%llu"

template<typename K> unsigned primitive_hash(const K& k) {
  unsigned hash = (unsigned)((uintptr_t)k);
  return hash ^ (hash >> 3); // just in case we're dealing with aligned ptrs
}

template<typename K> bool primitive_equals(const K& k0, const K& k1) {
  return k0 == k1;
}

#include "resourceHash.hpp"
#include "resourceHashNew.hpp"
#include "resourceHashX.hpp"

inline uintx test_modulo_const(uintx num) {
  return num % 6661;
}

inline uintx test_modulo(uintx num, uint *div) {
  return num % (*div);
}

volatile uint num = 0;
volatile uint keys[] = {0, 111, 222, 333, 444, 555, 666, 777, 888, 999};

uintx test_0(intx loops, uintx v) {
  for (intx i = 0; i < loops; i++) {
    v += test_modulo_const(v);
  }

  return v;
}

uintx test_1(intx loops, uintx v) {
  uint div = num + 6661;

  for (intx i = 0; i < loops; i++) {
    v += test_modulo(v, &div);
  }

  return v;
}

ResourceHashtable<uintx, uintx, 6661> table_2;

uintx test_2(intx loops, uint* keys, int num_keys) {
  uintx result = num;

  for (intx i = 0; i < loops; i++) {
    for (intx n = 0; n < num_keys; n++) {
      uintx* p = table_2.get(keys[n]);
      result += *p;
    }
  }

  return result;
}

ResourceHashtableNew<uintx, uintx> table_3(6661);

uintx test_3(intx loops, uint* keys, int num_keys) {
  uintx result = num;

  for (intx i = 0; i < loops; i++) {
    for (intx n = 0; n < num_keys; n++) {
      uintx* p = table_3.get(keys[n]);
      result += *p;
    }
  }

  return result;
}

ResourceHashtableXConst<uintx, uintx, 6661> table_4;

uintx test_4(intx loops, uint* keys, int num_keys) {
  uintx result = num;

  for (intx i = 0; i < loops; i++) {
    for (intx n = 0; n < num_keys; n++) {
      uintx* p = table_4.get(keys[n]);
      result += *p;
    }
  }
  return result;
}

ResourceHashtableXVar<uintx, uintx> table_5(6661);

uintx test_5(intx loops, uint* keys, int num_keys) {
  uintx result = num;

  for (intx i = 0; i < loops; i++) {
    for (intx n = 0; n < num_keys; n++) {
      uintx* p = table_5.get(keys[n]);
      result += *p;
    }
  }
  return result;
}


int test(int argc, char** argv) {
  if (argc < 3) {
    printf("Usage: %s <which> <loops>\n", argv[0]);
    exit(1);
  }
  intx which = atoll(argv[1]);
  intx loops = atoll(argv[2]);

  uintx v = (uintx)loops;

  switch (which) {
  case 0:
    v = test_0(loops, v);
    break;
  case 1:
    v = test_1(loops, v);
    break;
  case 2:
    for (int n = 0; n < 10; n++) {
      table_2.put(keys[n], 1);
    }
    v = test_2(loops, (uint*)keys, 10);
    break;
  case 3:
    for (int n = 0; n < 10; n++) {
      table_3.put(keys[n], 1);
    }
    v = test_3(loops, (uint*)keys, 10);
    break;
  case 4:
    for (int n = 0; n < 10; n++) {
      table_4.put(keys[n], 1);
    }
    v = test_4(loops, (uint*)keys, 10);
    break;
  case 5:
    for (int n = 0; n < 10; n++) {
      table_5.put(keys[n], 1);
    }
    v = test_5(loops, (uint*)keys, 10);
    break;
  }

  printf("which = %d v = " UINT64_FORMAT "\n", which, v);

  return (int)(v + v >> 32); // make sure the compiler doesn't elide the whole thing.
}

int main(int argc, char** argv) {
  test(argc, argv);
  return 0;
}
