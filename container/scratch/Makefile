# Run a dynamically linked app inside the "scratch" container image
#
# $ make dock
# ...
# REPOSITORY   TAG           IMAGE ID       CREATED         SIZE
# demo-app     0.1-scratch   2701289f6a88   4 minutes ago   2.38MB
#
# $ make run
# docker run -it --tty=true --rm demo-app:0.1-scratch /myapp
# Hello World

myapp: myapp.c
	gcc -o myapp myapp.c
	ldd myapp

dock: myapp
	mkdir -p lib/x86_64-linux-gnu
	mkdir -p lib64
	cp /lib/x86_64-linux-gnu/libc.so.6 lib/x86_64-linux-gnu
	cp /lib64/ld-linux-x86-64.so.2 lib64
	docker build -t demo-app:0.1-scratch -f Dockerfile .
	docker image ls demo-app:0.1-scratch

run:
	docker run -it --tty=true --rm demo-app:0.1-scratch /myapp

#alpine:
#	docker run -it --tty=true --rm 1.21.6-alpine3.18 /bash

#go: myapp
#	cp /bin/ldd .
#	docker build -t demo-app:golang -f Dockerfile.mygolang .
#	docker image ls demo-app:golang

#rungo:
#	docker run -it --tty=true --rm demo-app:golang


clean:
	rm -rf lib lib64 myapp *~ ldd
