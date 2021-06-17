ifndef CXX
CXX = g++
endif

test: test.cpp resourceHash.hpp resourceHashNew.hpp
	${CXX} -O3 -save-temps -o test test.cpp

run: test
	time ./test 0 100000000
	time ./test 1 100000000
	time ./test 2 100000000
	time ./test 3 100000000



clean:
	rm -f *~ *.o test *.s *.ii

