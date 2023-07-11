#include <stdio.h>

extern "C" int foo_exported();

class StringTable { // Used only by libfoo.a
 public:
  static int value();
};

int StringTable::value() { return 2; }

int main() {
  printf("foo_exported = %d\n", foo_exported());
  printf("StringTable::value() %d\n", StringTable::value());
}
