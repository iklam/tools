#include "foo.h"

int foo1() {
  return StringTable::value();
}

StringTable::StringTable() {
  x = 1000;
}


extern "C" int foo_exported() {
  return foo1() + foo2();
}
