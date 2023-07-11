#include "foo.h"

static StringTable tab;

int StringTable::value() {
  return 123;
}

int foo2() {
  return StringTable::value() + tab.x;
}
