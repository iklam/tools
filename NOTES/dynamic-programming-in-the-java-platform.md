# Dynamic Programming in the Java Platform

<center><i>DRAFT - ROUGH - DRAFT - ROUGH - DRAFT</i></center>

## 1. Introduction

Dynamic Programming has been an important tool for implementing the Java Platform. However, it has also been an obscure aspect for many JDK contributors. As we expect to see the usage of dynamic programming to grow in the Java Platform, we wrote this documentation for the following audience:

- Java programmers who need to understand, debug and improve the implementation for Lambda Expression, Core Reflection, String Concatentation, etc, in the Java Core Libraries.
- Java programmers who need to implement new features, or improve existing features that require efficient execution based on information available only during runtime.
- Java programmers who need to understand the concept, design and implementation of the building blocks for dynamic programming in the Java Platform: LambdaForm, MethodType, CallSites, ..., etc.
- C++ programmers who need to work on the handling of `invokedynamic`, `invokehandle` and `ldc` bytecodes, etc., in the HotSpot VM.


## History
Older Java platforms (up to JDK 6) were mostly implemented with C/C++, some assembler code, and what I call <i>Classical Bytecodes</i> -- these are all the bytecodes of the current [Java Virtual Machine Specification](https://docs.oracle.com/javase/specs/) except for the `invokedynamic` bytecode (`0xba`). [*1](#oldspec).

Classical bytecodes have a simple programming model. It's easy to write Java source code that are translated to classical bytecodes. In fact, many large scale application have been successfully developed this way.

However, there's one major problem with classical bytecodes -- it's difficult to write <i>Dynamic Programs</i> using just classical bytecodes.

In this document, Dynamic Programs are programs that can mutate to adapt to dynamic input. The first prominant examples are runtime engines for JVM-based scripting languages (JRuby, Jython, etc). Scripts written by these languages need to be translated to a representation that can be efficiently by the JVM. At first, many of the runtime engines generate Java class files from the scripts. (But that's not good enough, why?) JDK 7 introduced the `invokedynamic` bytecode and the `java.lang.invoke` APIs, which was described as ["dynamic language support provided directly by the Java core class libraries and virtual machine"](https://docs.oracle.com/javase/7/docs/api/java/lang/invoke/package-summary.html).

One often overlooked aspect of the `java.lang.invoke` APIs is that they don't just allow you to <i>invoke</i> Java code dynamically -- you can also <i>compose</i> Java code dynamically. This is a powerful mechanism that has been used to implement many parts of the Java Platform. In fact, the latest API documentation now describes `java.lang.invoke` as ["low-level primitives for interacting with the Java Virtual Machine"]("https://docs.oracle.com/en/java/javase/19/docs/api/java.base/java/lang/invoke/package-summary.html").

Over the years, many parts of the Java Platform have been implemented with dynamic programming:
- Lambda Expressions
- [JEP 280: Indify String Concatenation](https://openjdk.org/jeps/280)
- [JEP 416: Reimplement Core Reflection with Method Handles](https://openjdk.org/jeps/416)

Future features that will use dynamic programming
- [Lazy Static Final Fields](https://bugs.openjdk.org/browse/JDK-8209964)




## Notes

<a name="abcd">*1</a> In JVM Spec up to JDK 6, the `0xba` bytecode has the mnemonic `xxxunusedxxx` and is not supported. See
- https://docs.oracle.com/javase/specs/jvms/se6/html/VMSpecTOC.doc.html
- https://www.cs.miami.edu/home/burt/reference/java/language_vm_specification.pdf


# 2. Invocation and Composition with java.lang.invoke

Discover the structure of input 
  -> Generate handler based on the structure
     -> Invoke the handler with the input


Example: generate custom string concactenation handler (better example?)

# 3. Understanding JEP 280: Indify String Concatenation

- https://bugs.openjdk.org/browse/JDK-8295537
- https://bugs.openjdk.org/browse/JDK-8292699
- https://bugs.openjdk.org/secure/attachment/101204/str-concat.txt

# 4. Understand Lambda Expressions

(Draft ...... need tidying up and better text)

```
public class HelloLambda {
    public static void main(String[] args) throws Throwable  {
        doit(() -> {});
        System.out.println("===============================================");
        doit(() -> {
                System.out.println("Hello Lambda");
                Thread.dumpStack();
            });
    }

    static void doit(Runnable r) {
        r.run();
    }
}
```

```
$ mkdir -p DUMP_CLASS_FILES;
$ java -Djava.lang.invoke.MethodHandle.DUMP_CLASS_FILES=true \
       -Djdk.internal.lambda.dumpProxyClasses=DUMP_CLASS_FILES \
       -Djava.lang.invoke.MethodHandle.TRACE_METHOD_LINKAGE=true \
       -XX:+UnlockDiagnosticVMOptions -XX:+ShowHiddenFrames \
       -cp . HelloLambda
```

Look at the output below the "=====" line 
```
====================================================
linkCallSite HelloLambda.main(HelloLambda.java:19) java.lang.invoke.LambdaMetafactory.metafactory(Lookup,String,MethodType,MethodType,MethodHandle,MethodType)CallSite/invokeStatic run()Runnable/BSA=[()void, MethodHandle()void, ()void]
linkCallSite target class => java.lang.invoke.BoundMethodHandle$Species_L
linkCallSite target => ()Runnable : invoke000_L_L=Lambda(a0:L/SpeciesData[L => Species_L])=>{
    t1:L=Species_L.argL0(a0:L);t1:L}
& BMH=[
  0: ( HelloLambda$$Lambda$3/0x0000000801000c08@66d3c617 )
]
linkCallSite linkage => java.lang.invoke.Invokers$Holder.linkToTargetMethod(Object)Object/invokeStatic + MethodHandle()Runnable
Hello Lambda
java.lang.Exception: Stack trace
	at java.base/java.lang.Thread.dumpStack(Thread.java:2246)
	at HelloLambda.lambda$main$1(HelloLambda.java:21)
	at HelloLambda$$Lambda$3/0x0000000801000c08.run(Unknown Source)
	at HelloLambda.doit(HelloLambda.java:26)
	at HelloLambda.main(HelloLambda.java:19)

```

```
**********************************************************************

$ javap -c 'DUMP_CLASS_FILES/HelloLambda$$Lambda$7.class'
final class HelloLambda$$Lambda$7 implements java.lang.Runnable {
  public void run();
    Code:
       0: invokestatic  #16                 // Method HelloLambda.lambda$main$0:()V
       3: return
}

**********************************************************************

NOTE: the dump indicates that the target of the CallSite a BoundMethodHandle$Species_L,
which is a subclass of BoundMethodHandle:

    ======== CallSite: HelloLambda.main(HelloLambda.java:17)
    target class = java.lang.invoke.BoundMethodHandle$Species_L
    target = ()Runnable : invoke000_L_L=Lambda(a0:L/SpeciesData[L => Species_L])=>{
        t1:L=Species_L.argL0(a0:L);t1:L}
    & BMH=[
      0: ( HelloLambda$$Lambda$7/0x00000008010009f8@7440e464 )
    ]


$ javap 'java.lang.invoke.BoundMethodHandle$Species_L'
Compiled from "BoundMethodHandle.java"
final class java.lang.invoke.BoundMethodHandle$Species_L extends java.lang.invoke.BoundMethodHandle {
  final java.lang.Object argL0;
  [...snip....]
}

**********************************************************************

To understand how this MH is invoked, repeat the above "java" command in a fastdebug build with the
-XX:+TraceBytecodes flag, and find the following in the output:

    static jobject java.lang.invoke.MethodHandleNatives.linkCallSiteImpl(jobject, jobject, jobject, jobject, jobject, jobject)
     2213854    32  areturn
    
    static jobject java.lang.invoke.MethodHandleNatives.linkCallSite(jobject, jobject, jobject, jobject, jobject, jobject)
     2213855    48  areturn
    
    static jobject java.lang.invoke.Invokers$Holder.linkToTargetMethod(jobject)
     2213856     0  fast_aload_0
     2213857     1  checkcast 12 <java/lang/invoke/MethodHandle>
     2213858     4  invokehandle 56 <java/lang/invoke/MethodHandle.invokeBasic()Ljava/lang/Object;> 
    
    static jobject java.lang.invoke.LambdaForm$MH000/0x0000000800000400.invoke000_L_L(jobject)
     2213859     0  fast_aload_0
     2213860     1  checkcast 12 <java/lang/invoke/BoundMethodHandle$Species_L>
     2213861     4  fast_agetfield 16 <java/lang/invoke/BoundMethodHandle$Species_L.argL0/Ljava/lang/Object;> 
     2213862     7  areturn
    
    static jobject java.lang.invoke.Invokers$Holder.linkToTargetMethod(jobject)
     2213863     7  areturn
    
    static void HelloLambda.main(jobject)
     2213864     5  invokestatic 11 <HelloLambda.doit(Ljava/lang/Runnable;)V> 
    
    static void HelloLambda.doit(jobject)
     2213865     0  aload_0
     2213866     1  invokeinterface 17 <java/lang/Runnable.run()V> 

After the CallSite is linked, it's invoked with invoke000_L_L(target), which returns target.argL0, which is
an instance of HelloLambda$$Lambda$7, whose implementation of the interface method Runnable.run() calls
HelloLambda.lambda$main$0:(), which is the body of the Lambda expression in HelloLambda.java
```

# 5. LambdaForms