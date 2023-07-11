# Prototype for Hiding HotSpot Symbols in libjvm.a

HotSpot is usually built into a shared library (libjvm.so). Most of the symbols in libjvm.so are not exported, except a few symbols that are explicitly exported in these files

- https://github.com/openjdk/jdk/tree/master/make/data/hotspot-symbols

The symbol hiding is accomplished with the gcc flag `-fvisibility=hidden`  and ld flag `-Wl,--exclude-libs,ALL`

- https://github.com/openjdk/jdk/blob/master/make/common/modules/LibCommon.gmk

## Why doesn't this work for libjvm.a

libjvm.a is just a collector of all .o files in HotSpot. These .o files need symbols from each other.
For example, `init.o` has a reference to the symbol `StringTable::dump`, which is defined in stringTabl.o.

When linking an application statically, like

```
    gcc app.o libjvm.a
```

There's no way to tell the GNU linker that

- I want the .o files in libjvm.a to see all of each other's global symbols
- But I don't want app.o to see the `StringTable::StringTable` symbol in libjvm.a


## What can we do

We need to create libjvm.a in two steps:

- `ld --relocatable`: This combines all of HotSpot's .o files into a single combined .o file
- `objcopy -keep-global-symbols=file`: this hides all the symbols in the combined .o file, except those listed in the file


See [Makefile](Makefile) for a prototype.

Note that the symbol `StringTable::value()` is defined in both libjvm.a and app.o, but the one in 
libjvm.a is "local", as indicated by the lower case `t`, so it's not visible in the global linking scope.


```
$ make
gcc -c foo1.cpp
gcc -c foo2.cpp
ld --relocatable -o foo-combined.o foo1.o foo2.o
objcopy --keep-global-symbols=symbols-unix foo-combined.o foo-combined-stripped.o
rm -f libfoo.a
ar cr libfoo.a foo-combined-stripped.o
nm libfoo.a | c++filt

foo-combined-stripped.o:
0000000000000029 T foo_exported
00000000000000a3 t _GLOBAL__sub_I__ZN11StringTable5valueEv
0000000000000070 t __static_initialization_and_destruction_0(int, int)
0000000000000000 t foo1()
0000000000000059 t foo2()
0000000000000000 b tab
000000000000004a t StringTable::value()
0000000000000010 t StringTable::StringTable()
0000000000000010 t StringTable::StringTable()
gcc -c app.cpp
nm app.o | c++filt
                 U foo_exported
000000000000000f T main
                 U printf
0000000000000000 T StringTable::value()
gcc -o app app.o  -L . -lfoo

$ ./app
foo_exported = 1246
StringTable::value() 2
```

## References

- https://linux.die.net/man/1/ld
- https://man7.org/linux/man-pages/man1/objcopy.1.html
