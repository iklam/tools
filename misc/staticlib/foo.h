// foo.h

class StringTable { // Used only by libfoo.a
 public:
  int x;
  static int value();
  StringTable();
};


int foo1();
int foo2();
