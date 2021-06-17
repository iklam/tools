ifndef CXX
CXX = g++
endif

test: test.cpp resourceHash.hpp resourceHashNew.hpp resourceHashX.hpp
	${CXX} -O3 -save-temps -o test test.cpp

testg:
	${CXX} -g -save-temps -o test_g test.cpp

run: test
	@echo =============== modulo with const
	time ./test 0 100000000
	@echo
	@echo =============== modulo with variable
	time ./test 1 100000000
	@echo
	@echo =============== original ResourceHash with const SIZE == resourceHash.hpp
	time ./test 2 100000000
	@echo
	@echo =============== naive ResourceHash with variable _size  == resourceHashNew.hpp
	time ./test 3 100000000
	@echo
	@echo =============== extensible ResourceHash with const SIZE  == resourceHashX.hpp
	time ./test 4 100000000
	@echo
	@echo =============== extensible ResourceHash with variable SIZE == resourceHashX.hpp
	time ./test 5 100000000

clean:
	rm -f *~ *.o test *.s *.ii

