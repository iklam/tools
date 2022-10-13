# Some very basic Java test programs that you use a lot

all: HelloWorld.jar Lambda0.jar Concat0.jar ConcatMany.jar

clean:
	rm -rf *~ classes tmp *.jar *.jsa *.classlist

ifdef JAVA_HOME
JAVA  = $(JAVA_HOME)/bin/java
JAVAC = $(JAVA_HOME)/bin/javac
JAR   = $(JAVA_HOME)/bin/jar
else
JAVA  = java
JAVAC = javac
JAR   = jar
endif

define build
	rm -rf tmp
	mkdir -p tmp
	${JAVAC} -d tmp $1.java
	${JAR} cvf $1.jar -C tmp .
	mkdir -p classes
	mv tmp/* classes
	rm -rf tmp
endef


HelloWorld.jar: HelloWorld.java
	$(call build,HelloWorld)

Lambda0.jar: Lambda0.java
	$(call build,Lambda0)

Concat0.jar: Concat0.java
	$(call build,Concat0)

ConcatMany.jar: ConcatMany.java
	$(call build,ConcatMany)

