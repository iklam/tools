JAVA_HOME := /jdk3/official/jdk25
ASMTOOL = /jdk3/official/jtreg7.4.1/lib/asmtools.jar
JAVA    = ${JAVA_HOME}/bin/java
JAVAC   = ${JAVA_HOME}/bin/javac
JAR     = ${JAVA_HOME}/bin/jar
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

define QuickBuildVal
    $(call MakeTmpClasses)
    ${TESTBED}/bin/javac \
	--enable-preview -source 28 \
	--add-exports java.base/jdk.internal.value=ALL-UNNAMED \
	--add-exports java.base/jdk.internal.vm.annotation=ALL-UNNAMED \
	-d tmpclasses $1.java
    $(call MakeJarAndCleanup, $1)
endef

ALL_JARS = \
    CharsetTest.jar \
    CodeSourceTest.jar \
    CustomLoaderGC.jar \
    HelloLoop.jar \
    HelloWorld.jar \
    IntLoop.jar \
    JavacBench2.jar \
    JavacHelloWorld.jar \
    LambdaLoop.jar \
    LambdaMisc.jar \
    MathUtilsTest.jar \
    MySysLoader.jar \
    NumberCacheTest.jar \
    OldClass.jar \
    ReflectExcludedClass.jar \
    Wait.jar \
    modules/HelloModule.jar

VAL_JARS = \
    HelloVal.jar

all: ${ALL_JARS}
	@ls -l $$(for i in $$(echo ${ALL_JARS} | sort); do echo ${HOME}/tmp/$$i; done)

val: ${VAL_JARS}

CharsetTest.jar: CharsetTest.java
	$(call QuickBuild, CharsetTest)

CodeSourceTest.jar: CodeSourceTest.java
	$(call QuickBuild, CodeSourceTest)

CustomLoaderGC.jar: CustomLoaderGC.java
	$(call QuickBuild, CustomLoaderGC)

JavacBench2.jar: JavacBench2.java
	$(call QuickBuild, JavacBench2)

HelloVal.jar: HelloVal.java
	$(call QuickBuildVal, HelloVal)

HelloLoop.jar: HelloLoop.java
	$(call QuickBuild, HelloLoop)

HelloWorld.jar: HelloWorld.java
	$(call QuickBuild, HelloWorld)

IntLoop.jar: IntLoop.java
	$(call QuickBuild, IntLoop)

JavacHelloWorld.jar: JavacHelloWorld.java
	$(call QuickBuild, JavacHelloWorld)

LambdaLoop.jar: LambdaLoop.java
	$(call QuickBuild, LambdaLoop)

LambdaMisc.jar: LambdaMisc.java
	$(call QuickBuild, LambdaMisc)

MathUtilsTest.jar: MathUtilsTest.java
	$(call QuickBuild, MathUtilsTest)

MySysLoader.jar: MySysLoader.java
	$(call QuickBuild, MySysLoader)

NumberCacheTest.jar: NumberCacheTest.java
	$(call QuickBuild, NumberCacheTest)

OldClass.jar: OldClass.java OldA.jasm OldClassWithVerifierConstraints.jasm OldClassWithBadVerifierConstraints.jasm
	$(call MakeTmpClasses)
	${JASM} -d tmpclasses OldA.jasm OldClassWithVerifierConstraints.jasm OldClassWithBadVerifierConstraints.jasm
	${JAVAC} -cp tmpclasses -d tmpclasses OldClass.java
	$(call MakeJarAndCleanup, OldClass)

ReflectExcludedClass.jar: ReflectExcludedClass.java
	$(call QuickBuild, ReflectExcludedClass)

Wait.jar: Wait.java
	$(call QuickBuild, Wait)

modules/HelloModule.jar: moda/module-info.java moda/moda/HelloModule.java
	rm -rf tmpmod
	mkdir -p tmpmod modules ${HOME}/tmp/modules
	${JAVAC} -d tmpmod moda/moda/HelloModule.java moda/module-info.java 
	${JAR} --create --file modules/HelloModule.jar --main-class moda.HelloModule -C tmpmod .
	cp modules/HelloModule.jar ${HOME}/tmp/modules
	rm -rf xtmpmod

clean:
	rm -rf *~ ${ALL_JARS} tmpclasses *.aot *.aot.config *.aotconfig *.class *.jsa *.config *.classlist tmpmod
