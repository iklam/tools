# https://linux.die.net/man/1/ld
# https://man7.org/linux/man-pages/man1/objcopy.1.html

all: app

libfoo.a: foo1.cpp foo2.cpp Makefile
	gcc -c foo1.cpp
	gcc -c foo2.cpp
	ld --relocatable -o foo-combined.o foo1.o foo2.o
	objcopy --keep-global-symbols=symbols-unix foo-combined.o foo-combined-stripped.o
	rm -f libfoo.a
	ar cr libfoo.a foo-combined-stripped.o
	nm libfoo.a | c++filt

app: app.cpp libfoo.a Makefile
	gcc -c app.cpp
	nm app.o | c++filt
	gcc -o app app.o  -L . -lfoo

clean:
	rm -f *.o *~ *.a


