# Some very basic Java test programs that you use a lot

all: HelloWorld.jar Lambda0.jar

clean:
	rm -rf *~ classes tmp *.jar *.jsa *.classlist

ifdef JDK8_HOME
JAVA  = $(JDK8_HOME)/bin/java
JAVAC = $(JDK8_HOME)/bin/javac
JAR   = $(JDK8_HOME)/bin/jar
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


