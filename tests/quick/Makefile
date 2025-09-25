ASMTOOL = /jdk3/official/jtreg7.4.1/lib/asmtools.jar
JAVA    = ${GOODJAVAHOME}/bin/java
JAVAC   = ${GOODJAVAHOME}/bin/javac
JAR     = ${GOODJAVAHOME}/bin/jar
JASM    = ${JAVA} -jar ${ASMTOOL} jasm

define MakeTmpClasses
    rm -rf tmpclasses
    mkdir tmpclasses
endef

define MakeJarAndCleanup
    ${JAR} c0f $1.jar -C tmpclasses .
    rm -rf tmpclasses
    cp $1.jar ${HOME}/tmp
endef

define QuickBuild
    $(call MakeTmpClasses)
    ${JAVAC} -d tmpclasses $1.java
    $(call MakeJarAndCleanup, $1)
endef

ALL_JARS = \
    CharsetTest.jar \
    HelloWorld.jar \
    LambdaMisc.jar \
    MathUtilsTest.jar \
    NumberCacheTest.jar \
    OldClass.jar \
    ReflectExcludedClass.jar

all: ${ALL_JARS}
	@ls -l $$(for i in $$(echo ${ALL_JARS} | sort); do echo ${HOME}/tmp/$$i; done)

CharsetTest.jar: CharsetTest.java
	$(call QuickBuild, CharsetTest)

HelloWorld.jar: HelloWorld.java
	$(call QuickBuild, HelloWorld)

LambdaMisc.jar: LambdaMisc.java
	$(call QuickBuild, LambdaMisc)

MathUtilsTest.jar: MathUtilsTest.java
	$(call QuickBuild, MathUtilsTest)

NumberCacheTest.jar: NumberCacheTest.java
	$(call QuickBuild, NumberCacheTest)

OldClass.jar: OldClass.java OldA.jasm OldClassWithVerifierConstraints.jasm OldClassWithBadVerifierConstraints.jasm
	$(call MakeTmpClasses)
	${JASM} -d tmpclasses OldA.jasm OldClassWithVerifierConstraints.jasm OldClassWithBadVerifierConstraints.jasm
	${JAVAC} -cp tmpclasses -d tmpclasses OldClass.java
	$(call MakeJarAndCleanup, OldClass)

ReflectExcludedClass.jar: ReflectExcludedClass.java
	$(call QuickBuild, ReflectExcludedClass)

clean:
	rm -rf *~ ${ALL_JARS} tmpclasses
