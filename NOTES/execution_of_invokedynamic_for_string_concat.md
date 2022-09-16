# The Execution of Invokedynamic Bytecodes for String Concatenation

The execution of the `invokedynamic` bytecode is complex and hard to understand. In this document,
I'll walk through all the steps for executing an `invokedynamic` bytecode used for string concatenation
(see [JEP 280: Indify String Concatenation](https://openjdk.org/jeps/280)).

Note - I'll only discuss what happens AFTER the `invokedynamic` bytecode has been linked (i.e., the
Bootstrap method (BSM) has been executed). Linking is a much more complex topic that I won't go into for now.

First let's create a simple example:


```
public class Concat0 {
    static String s = "1";
    static String d;
    public static void main(String args[]) {
        for (int i = 0; i < 2; i++) {
            d = "000" + Concat0.s;
        }
    }
}
```

Let's look at the bytecodes -- we have an `invokedynamic` bytecode at location 10 of the `main` method. Note that
we use a loop to execute this bytecode twice. On the first execution, the BSM is executed to link the bytecode.
We'll just look at what happens on the second execution of the `invokedynamic`, where the BSM is no longer involved.


```
$ javap -c Concat0.class
...
public static void main(java.lang.String[]);
  Code:
     0: iconst_0
     1: istore_1
     2: iload_1
     3: iconst_2
     4: if_icmpge     24
     7: getstatic     #7         // Field s:Ljava/lang/String;
    10: invokedynamic #13,  0    // InvokeDynamic #0:makeConcatWithConstants:(Ljava/lang/String;)Ljava/lang/String;
    15: putstatic     #17        // Field d:Ljava/lang/String;
    18: iinc          1, 1
    21: goto          2
    24: return
```

To see all the bytecodes that are executed for this small program, do this with a debug JDK. With JDK 20,
you should see only three `invokedynamic` bytecodes being executed, so you can easily find the interesting stuff.
Also, make sure CDS is enabled -- this reduces the number of total bytecodes from about 2 million to about 400,000.

```
$ java -Xint -XX:+TraceBytecodes -cp . Concat0 > Concat0.trace
$ grep -n invokedynamic Concat0.trace
143714:[152962]   114067    22  invokedynamic bsm=141 43 <apply(Ljava/security/SecureClassLoader;Ljava/security/CodeSource;)Ljava/util/function/Function;>
277526:[152962]   218596    10  invokedynamic bsm=31 13 <makeConcatWithConstants(Ljava/lang/String;)Ljava/lang/String;>
519705:[152962]   406889    10  invokedynamic bsm=31 13 <makeConcatWithConstants(Ljava/lang/String;)Ljava/lang/String;>
```

Open the `Concat0.trace` file in an editor and find the following block from around line 519705. You can see eventually
we come to the method
[`java.lang.StringConcatHelper.simpleConcat(Object, Object)`](https://github.com/openjdk/jdk/blob/9a40b76ac594f5bd80e74ee906af615f74f9a41a/src/java.base/share/classes/java/lang/StringConcatHelper.java#L350),
which performs the actual concatenation.

```
static void Concat0.main(jobject)
  406882    15  putstatic 17 <Concat0.d/Ljava/lang/String;> 
  406883    18  iinc #1 1
  406884    21  goto 2
  406885     2  iload_1
  406886     3  iconst_2
  406887     4  if_icmpge 24
  406888     7  getstatic 7 <Concat0.s/Ljava/lang/String;> 
  406889    10  invokedynamic bsm=31 13 <makeConcatWithConstants(Ljava/lang/String;)Ljava/lang/String;>

static jobject java.lang.invoke.Invokers$Holder.linkToTargetMethod(jobject, jobject)
  406890     0  aload_1
  406891     1  checkcast 12 <java/lang/invoke/MethodHandle>
  406892     4  nofast_aload_0
  406893     5  invokehandle 28 <java/lang/invoke/MethodHandle.invokeBasic(Ljava/lang/Object;)Ljava/lang/Object;> 

static jobject java.lang.invoke.LambdaForm$MH/0x0000000801000400.invoke(jobject, jobject)
  406894     0  fast_aload_0
  406895     1  checkcast 12 <java/lang/invoke/BoundMethodHandle$Species_LL>
  406896     4  dup
  406897     5  astore_0
  406898     6  fast_agetfield 16 <java/lang/invoke/BoundMethodHandle$Species_LL.argL1/Ljava/lang/Object;> 
  406899     9  astore_2
  406900    10  aload_0
  406901    11  fast_agetfield 19 <java/lang/invoke/BoundMethodHandle$Species_LL.argL0/Ljava/lang/Object;> 
  406902    14  astore_3
  406903    15  aload_3
  406904    16  checkcast 21 <java/lang/invoke/MethodHandle>
  406905    19  aload_2
  406906    20  aload_1
  406907    21  invokehandle 24 <java/lang/invoke/MethodHandle.invokeBasic(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;> 

static jobject java.lang.invoke.DirectMethodHandle$Holder.invokeStatic(jobject, jobject, jobject)
  406908     0  nofast_aload_0
  406909     1  invokestatic 16 <java/lang/invoke/DirectMethodHandle.internalMemberName(Ljava/lang/Object;)Ljava/lang/Object;> 

static jobject java.lang.invoke.DirectMethodHandle.internalMemberName(jobject)
  406910     0  nofast_aload_0
  406911     1  checkcast 3 <java/lang/invoke/DirectMethodHandle>
  406912     4  nofast_getfield 80 <java/lang/invoke/DirectMethodHandle.member/Ljava/lang/invoke/MemberName;> 
  406913     7  areturn

static jobject java.lang.invoke.DirectMethodHandle$Holder.invokeStatic(jobject, jobject, jobject)
  406914     4  astore_3
  406915     5  aload_1
  406916     6  aload_2
  406917     7  aload_3
  406918     8  checkcast 21 <java/lang/invoke/MemberName>
  406919    11  invokestatic 257 <java/lang/invoke/MethodHandle.linkToStatic
                  (Ljava/lang/Object;Ljava/lang/Object;Ljava/lang/invoke/MemberName;)Ljava/lang/Object;> 

static jobject java.lang.StringConcatHelper.simpleConcat(jobject, jobject)
  406920     0  nofast_aload_0
```

The rest of the document discusses all the intermediate steps that take us from `Concat0.main()`
to `StringConcatHelper.simpleConcat()`.

To make it easier to examine the bytecodes, first apply [this patch](https://github.com/openjdk/jdk/pull/9957)
and then build a slowdebug variant of the JDK. Without this patch, you will need to manually
look up all the methods and constant pools involved in the execution, which may be very tedious. 

Then, load the JDK inside gdb. Set a breakpoint at `exit_globals()` and start running the `Concat0` class. After `Concat0.main()` has
finished, you will land in `exit_globals()`. Use the `findmethod` function introduced by the above patch to
examine the `Concat0.main()` method. Note that you can use the bitmask in the thrid parameter to control
what gets printed:


```
$ gdb --args java -cp . -Xint Concat0
(gdb) b exit_globals
(gdb) call findmethod("Concat0", "main", 0x8)

"Executing findmethod"
flags (bitmask):
   0x01  - print names of methods
   0x02  - print bytecodes
   0x04  - print the address of bytecodes
   0x08  - print info for invokedynamic
   0x10  - print info for invokehandle

[  0] 0x0000000801000800 Concat0 loader data: 0x00007ffff021f8c0 for instance a 'jdk/internal/loader/ClassLoaders$AppClassLoader'{0x00000007ff859358}
0x00007fffb4400378 main : ([Ljava/lang/String;)V
   0 iconst_0
   1 istore_1
   2 iload_1
   3 iconst_2
   4 if_icmpge 24
   7 getstatic 7 <Concat0.s/Ljava/lang/String;> 
  10 invokedynamic bsm=31 13 <makeConcatWithConstants(Ljava/lang/String;)Ljava/lang/String;>
  BSM: REF_invokeStatic 32 <java/lang/invoke/StringConcatFactory.makeConcatWithConstants(Ljava/lang/invoke/MethodHandles$Lookup;Ljava/lang/String;Ljava/lang/invoke/MethodType;Ljava/lang/String;[Ljava/lang/Object;)Ljava/lang/invoke/CallSite;> 
  arguments[1] = {
     0
  }
  ConstantPoolCacheEntry:   4  (0x00007fffb4400588)  [00|ba|   13]
                 [   0x00000008000f13a0]
                 [   0x0000000000000003]
                 [   0xffffffff83400002]
                 -------------
  Method: 0x00000008000f13a0 java/lang/invoke/Invokers$Holder.linkToTargetMethod(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;
  appendix: java.lang.invoke.BoundMethodHandle$Species_LL 
{0x000000062d826ad8} - klass: 'java/lang/invoke/BoundMethodHandle$Species_LL'
 - ---- fields (total size 5 words):
 - private 'customizationCount' 'B' @12  0
 - private volatile 'updateInProgress' 'Z' @13  false
 - private final 'type' 'Ljava/lang/invoke/MethodType;' @16  a 'java/lang/invoke/MethodType'{0x000000062d81ed50}
          = (Ljava/lang/String;)Ljava/lang/String; (c5b03daa)
 - final 'form' 'Ljava/lang/invoke/LambdaForm;' @20  a 'java/lang/invoke/LambdaForm'{0x000000062d823560}
          => a 'java/lang/invoke/MemberName'{0x000000062d826960}
             = {method} {0x00007fffb44012e0} 'invoke' '(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;'
                 in 'java/lang/invoke/LambdaForm$MH+0x0000000801000400' (c5b046ac)
 - private 'asTypeCache' 'Ljava/lang/invoke/MethodHandle;' @24  NULL (0)
 - private 'asTypeSoftCache' 'Ljava/lang/ref/SoftReference;' @28  NULL (0)
 - final 'argL0' 'Ljava/lang/Object;' @32  a 'java/lang/invoke/DirectMethodHandle'{0x000000062d81f830} (c5b03f06)
 - final 'argL1' 'Ljava/lang/Object;' @36  "000"{0x000000062d81f290} (c5b03e52)
  15 putstatic 17 <Concat0.d/Ljava/lang/String;> 
  18 iinc #1 1
  21 goto 2
  24 return
```

Since the JVM has already finished executing `Concat0.main()` and is exiting, the `invokedynamic` bytecode at 10 has
already been resolved. Its `ConstantPoolCacheEntry` points to two important things:

- A C++ `Method` pointer to `Invokers$Holder.linkToTargetMethod(Object, Object)` at address `0x00000008000f13a0`.
- An "appendix" oop of the type `java.lang.invoke.BoundMethodHandle$Species_LL` at `0x000000062d826ad8`

Note that the bytecodes leading up to the invokedynamic look like this

```
static void Concat0.main(jobject)
  406882    15  putstatic 17 <Concat0.d/Ljava/lang/String;> 
  406883    18  iinc #1 1
  406884    21  goto 2
  406885     2  iload_1
  406886     3  iconst_2
  406887     4  if_icmpge 24
  406888     7  getstatic 7 <Concat0.s/Ljava/lang/String;> 
  406889    10  invokedynamic bsm=31 13 <makeConcatWithConstants(Ljava/lang/String;)Ljava/lang/String;>
```

So the Java stack already has one item, the String from the static field `Concat0.s`. The interpreter executes the
invokedynamic bytecode like this:

- push the "appendix" object object into the stack
- jump to the `Invokers$Holder.linkToTargetMethod(Object, Object)` method.

The following are the bytecodes that are executed inside `linkToTargetMethod`:

```
static jobject java.lang.invoke.Invokers$Holder.linkToTargetMethod(jobject, jobject)
  406890     0  aload_1
  406891     1  checkcast 12 <java/lang/invoke/MethodHandle>
  406892     4  nofast_aload_0
  406893     5  invokehandle 28 <java/lang/invoke/MethodHandle.invokeBasic(Ljava/lang/Object;)Ljava/lang/Object;> 
```

The `invokehandle` bytecode at bytecode number 5 is resolved like this:

```
(gdb) call findmethod2("java/lang/invoke/Invokers$Holder", "linkToTargetMethod",
            "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;", 0x10)
[  0] 0x00000008000f0770 java/lang/invoke/Invokers$Holder loader data: 0x00007ffff0132ec0 of 'bootstrap'
0x00000008000f13a0 linkToTargetMethod : (Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;
   0 aload_1
   1 checkcast 12 <java/lang/invoke/MethodHandle>
   4 nofast_aload_0
   5 invokehandle 28 <java/lang/invoke/MethodHandle.invokeBasic(Ljava/lang/Object;)Ljava/lang/Object;> 
  ConstantPoolCacheEntry:   2  (0x00000008000f0a70)  [00|e9|   28]
                 [   0x00007fffb4023f30]
                 [   0x0000000000000015]
                 [   0xffffffff82400002]
                 -------------
  Method (native): 0x00007fffb4023f30 java/lang/invoke/MethodHandle.invokeBasic(Ljava/lang/Object;)Ljava/lang/Object;
   8 areturn
```

So essentially, `linkToTargetMethod()` works like this:

```
((MethodHandle)appendix).invokeBasic(Concat0.s)
```

You may wonder why the bytecode trace suddenly jumps to `LambdaForm$MH/0x0000000801000400.invoke`:

```
[152962] static jobject java.lang.invoke.Invokers$Holder.linkToTargetMethod(jobject, jobject)
  406890     0  aload_1
  406891     1  checkcast 12 <java/lang/invoke/MethodHandle>
  406892     4  nofast_aload_0
  406893     5  invokehandle 28 <java/lang/invoke/MethodHandle.invokeBasic(Ljava/lang/Object;)Ljava/lang/Object;> 
 |
 |  huh??
 V
static jobject java.lang.invoke.LambdaForm$MH/0x0000000801000400.invoke(jobject, jobject)
  406894     0  fast_aload_0
```

That's because [MethodHandle.invokeBasic()](https://github.com/openjdk/jdk/blob/3beca2db0761f8172614bf1b287b694c8595b498/src/java.base/share/classes/java/lang/invoke/MethodHandle.java#L562)
is actually a native method. You can see its implementation in here:

- [Method handle dispatch for `vmIntrinsics::_invokeBasic`](https://github.com/openjdk/jdk/blob/3beca2db0761f8172614bf1b287b694c8595b498/src/hotspot/cpu/x86/methodHandles_x86.cpp#L355-L357)
- [Jumping to MethodHandle::form](https://github.com/openjdk/jdk/blob/3beca2db0761f8172614bf1b287b694c8595b498/src/hotspot/cpu/x86/methodHandles_x86.cpp#L165-L186)

The `invokeBasic()` method operates on the "appendix" object of the cpcache entry we saw earlier:

```
{0x000000062d826ad8} - klass: 'java/lang/invoke/BoundMethodHandle$Species_LL'
 - final 'form' 'Ljava/lang/invoke/LambdaForm;' @20  a 'java/lang/invoke/LambdaForm'{0x000000062d823560} =>
   a 'java/lang/invoke/MemberName'{0x000000062d826960} = 
       {method} {0x00007fffb44012e0} 'invoke' '(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;'
                in 'java/lang/invoke/LambdaForm$MH+0x0000000801000400' (c5b046ac)
 - final 'argL0' 'Ljava/lang/Object;' @32  a 'java/lang/invoke/DirectMethodHandle'{0x000000062d81f830} (c5b03f06)
 - final 'argL1' 'Ljava/lang/Object;' @36  "000"{0x000000062d81f290} (c5b03e52)
```

Essentially `invokeBasic()` does this:

```
LambdaForm f = this.form;                // Java
MemberName mn = f.vmentry;               // Java
ResolvedMethodName rmn = nm.method;      // Java
Method* method = (Method*)rmn.vmtarget;  // C++
jump_from_method_handle(method, ...);    // assembler
```

Since `this.form` points to the method `LambdaForm$MH+0x0000000801000400.invoke()`, that's
how the interpreter starts executing in there. At the entry of this method, we have two parameters:

- local0 is the "appendix" object from above (`0x000000062d826ad8` - an instance of `BoundMethodHandle$Species_LL`)
- local1 is the "variable" part of the concatenation (the string in `Concat0.s`)

Recall that our concatenation looks like this:

```
d = "000" + Concat0.s;
```

The `"000"` part of the concatenation is considered a "constant", so it's not passed as a parameter by
the `invokedynamic` bytecode. Instead, it's recorded inside the appendix object. You can see
it being loaded by the following code (from the `argL1` field of the appendix object on bytecode 6):

```
static jobject java.lang.invoke.LambdaForm$MH/0x0000000801000400.invoke(jobject, jobject)
  406894     0  fast_aload_0
  406895     1  checkcast 12 <java/lang/invoke/BoundMethodHandle$Species_LL>
  406896     4  dup
  406897     5  astore_0
  406898     6  fast_agetfield 16 <java/lang/invoke/BoundMethodHandle$Species_LL.argL1/Ljava/lang/Object;> 
  406899     9  astore_2
  406900    10  aload_0
  406901    11  fast_agetfield 19 <java/lang/invoke/BoundMethodHandle$Species_LL.argL0/Ljava/lang/Object;> 
  406902    14  astore_3
  406903    15  aload_3
  406904    16  checkcast 21 <java/lang/invoke/MethodHandle>
  406905    19  aload_2
  406906    20  aload_1
  406907    21  invokehandle 24 <java/lang/invoke/MethodHandle.invokeBasic(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;> 
```

The above is essentially doing:

```
MethodHandle mh = this.argL0;        // 0x000000062d81f830, an instance of DirectMethodHandle
mh.invokeBasic(this.argL1, local1);  // "000", Concat0.s
```

We see another call to `invokeBasic`, which loads `mh.form` and eventually jumps to the `Method*`. This time, `mh` looks like this:

```
{0x000000062d81f830} - klass: 'java/lang/invoke/DirectMethodHandle'
 ...
 - final 'form' 'Ljava/lang/invoke/LambdaForm;' @20  a 'java/lang/invoke/LambdaForm'{0x000000062d81f718}
       => a 'java/lang/invoke/MemberName'{0x000000062d81f7c0} = 
          {method} {0x00000008000f6bb8} 'invokeStatic' '(Ljava/lang/Object;Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;'
             in 'java/lang/invoke/DirectMethodHandle$Holder' (c5b03ee3)
 - final 'member' 'Ljava/lang/invoke/MemberName;' @32  a 'java/lang/invoke/MemberName'{0x000000062d81f3c0}
        = {method} {0x00000008004b59d0} 'simpleConcat' '(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/String;'
             in 'java/lang/StringConcatHelper' (c5b03e78)
```

So we end up inside `java/lang/invoke/DirectMethodHandle$Holder.invokeStatic`:

```
static jobject java.lang.invoke.DirectMethodHandle$Holder.invokeStatic(jobject, jobject, jobject)
  406908     0  nofast_aload_0
  406909     1  invokestatic 16 <java/lang/invoke/DirectMethodHandle.internalMemberName(Ljava/lang/Object;)Ljava/lang/Object;> 

static jobject java.lang.invoke.DirectMethodHandle.internalMemberName(jobject)
  406910     0  nofast_aload_0
  406911     1  checkcast 3 <java/lang/invoke/DirectMethodHandle>
  406912     4  nofast_getfield 80 <java/lang/invoke/DirectMethodHandle.member/Ljava/lang/invoke/MemberName;> 
  406913     7  areturn

static jobject java.lang.invoke.DirectMethodHandle$Holder.invokeStatic(jobject, jobject, jobject)
  406914     4  astore_3
  406915     5  aload_1
  406916     6  aload_2
  406917     7  aload_3
  406918     8  checkcast 21 <java/lang/invoke/MemberName>
  406919    11  invokestatic 257 <java/lang/invoke/MethodHandle.linkToStatic
                  (Ljava/lang/Object;Ljava/lang/Object;Ljava/lang/invoke/MemberName;)Ljava/lang/Object;> 
```

Which essentially does this:

```
invokeStatic(DirectMethodHandle dmh, Object s1, Object s2) {
    MemberName mn = this.member;           // = StringConcatHelper.simpleConcat
    MethodHandle.linkToStatic(mn, s1, s2); // s1 == "000", s2 == Concat0.s
```

[`MethodHandle.linkToStatic`](https://github.com/openjdk/jdk/blob/3beca2db0761f8172614bf1b287b694c8595b498/src/java.base/share/classes/java/lang/invoke/MethodHandle.java#L584)
is similar to `MethodHandle.invokeBasic`. It's also a native method implemented in
[here](https://github.com/openjdk/jdk/blob/3beca2db0761f8172614bf1b287b694c8595b498/src/hotspot/cpu/x86/methodHandles_x86.cpp#L428-L434),
which does the following

```
linkToStatic(MemberName mn, args ...) {
    ResolvedMethodName rmn = param0.method;    // Java
    Method* method = (Method*)rmn.vmtarget;    // C++
    jump_from_method_handle(method, ...);      // assembler

```

and we finally arrive at our destination:

```
static jobject java.lang.invoke.DirectMethodHandle$Holder.invokeStatic(jobject, jobject, jobject)
  ...
  406919    11  invokestatic 257 <java/lang/invoke/MethodHandle.linkToStatic(Ljava/lang/Object;Ljava/lang/Object;Ljava/lang/invoke/MemberName;)Ljava/lang/Object;> 
   |
   | (assembler code)
   V
static jobject java.lang.StringConcatHelper.simpleConcat(jobject, jobject)
  406920     0  nofast_aload_0
```

## Examining the Callstack

You can add this to StringConcatHelper.java and rebuild the JDK:

```
static String simpleConcat(Object first, Object second) {
    if (first.equals("000")) {
        Thread.dumpStack();
    }
```

Running the `Concat0` class again shows the callstack:

```
$ java -XX:+UnlockDiagnosticVMOptions -XX:+ShowHiddenFrames -cp . Concat0
java.lang.Exception: Stack trace
	at java.base/java.lang.Thread.dumpStack(Thread.java:2282)
	at java.base/java.lang.StringConcatHelper.simpleConcat(StringConcatHelper.java:352)
	at java.base/java.lang.invoke.DirectMethodHandle$Holder.invokeStatic(DirectMethodHandle$Holder)
	at java.base/java.lang.invoke.LambdaForm$MH/0x0000000801000400.invoke(LambdaForm$MH)
	at java.base/java.lang.invoke.Invokers$Holder.linkToTargetMethod(Invokers$Holder)
	at Concat0.main(Concat0.java:18)
```

Note that we don't see a call frame for `MethodHandle.invokeBasic()` or `MethodHandle.linkToStatic()`.
These two methods are essentially tail calls -- their own callframe gets taken over by the
target method.
