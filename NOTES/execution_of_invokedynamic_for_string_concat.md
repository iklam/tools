# The Execution of Invokedynamic Bytecodes for String Concatenation

The execution of the `invokedynamic` bytecode is complex and hard to understand. In this document, I'll walk through all the steps for executing an `invokedynamic` bytecode used for string concatenation (see [JEP 280: Indify String Concatenation](https://openjdk.org/jeps/280)).

Note - I'll only discuss what happens AFTER the `invokedynamic` bytecode has been linked (i.e., the Bootstrap method (BSM) has been executed). Linking is a much more complex topic that I won't go into for now.


First let's create a simple example:


```
public class Concat0 {
    static String s = "1";
    static String d;
    public static void main(String args[]) {
        for (int i = 0; i < 2; i++) {
            d = "0" + s;
        }
    }
}
```

Let's look at the bytecodes -- we have an `invokedynamic` bytecode at location 10 of the `main` method. Note that we use a loop to execute this bytecode twice. On the first execution, the BSM is executed to link the bytecode. We'll just look at what happens on the second execution of the `invokedynamic`, where the BSM is no longer involved.


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
you should see only three invokedynamic bytecode being executed, so you can easily find the interesting stuff.
Also, make sure CDS is enabled -- this reduces the number of total bytecodes from about 2 million to about 400,000.

```
$ java -Xint -XX:+TraceBytecodes -cp . Concat0 > Concat0.trace
$ grep -n invokedynamic Concat0.trace
143714:[152962]   114067    22  invokedynamic bsm=141 43 <apply(Ljava/security/SecureClassLoader;Ljava/security/CodeSource;)Ljava/util/function/Function;>
277526:[152962]   218596    10  invokedynamic bsm=31 13 <makeConcatWithConstants(Ljava/lang/String;)Ljava/lang/String;>
519705:[152962]   406889    10  invokedynamic bsm=31 13 <makeConcatWithConstants(Ljava/lang/String;)Ljava/lang/String;>
```

Open the `Concat0.trace` file in an editor and find the following block from around line 519705. You can see eventually we arrive into the method [`java.lang.StringConcatHelper.simpleConcat(Object, Object)`](https://github.com/openjdk/jdk/blob/9a40b76ac594f5bd80e74ee906af615f74f9a41a/src/java.base/share/classes/java/lang/StringConcatHelper.java#L350), which performs the actual concatenation.

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
  406919    11  invokestatic 257 <java/lang/invoke/MethodHandle.linkToStatic(Ljava/lang/Object;Ljava/lang/Object;Ljava/lang/invoke/MemberName;)Ljava/lang/Object;> 

static jobject java.lang.StringConcatHelper.simpleConcat(jobject, jobject)
  406920     0  nofast_aload_0
```

The rest of the document discusses all the intermediate steps that take us from `Concat0.main()` to `StringConcatHelper.simpleConcat()`.

