# Notes on HotSpot AOT Implementation (2026)

## 1. Overview

This document is intended to provide a few "getting started" pointers to the HotSpot
implementation of AOT (Ahead Of Time) features in the HotSpot JVM.

The target audience is HotSpot engineers who want to know how AOT works, and how AOT
interacts with other parts of the JVM.

External Doc Links:

- [Project Leyden](https://openjdk.org/projects/leyden/)
- [JEP 483](https://openjdk.org/jeps/483): Ahead-of-Time Class Loading & Linking
- [JEP 514](https://openjdk.org/jeps/514): Ahead-of-Time Command-Line Ergonomics
- [JEP 515](https://openjdk.org/jeps/515): Ahead-of-Time Method Profiling
- [JEP ???](https://openjdk.org/jeps/8335368): Ahead-of-Time Code Compilation

All GIT URLs given below are from the version

- [https://github.com/openjdk/jdk/commit/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b](https://github.com/openjdk/jdk/commit/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b), around 2026/04/06

Note: a lot of the code still uses the historical term "CDS". We will eventually move all code to say "AOT".

## 2. AOT Workflow

Training run: gather application profile:

```
java -cp HelloWorld.jar -XX:AOTMode=record -XX:AOTConfiguration=hw.aotconfig HelloWorld
```

Assembly phase: create AOT cache (`hw.aot`) from the profile (`hw.aotconfig`)

```
java -cp HelloWorld.jar -XX:AOTMode=create -XX:AOTConfiguration=hw.aotconfig \
    -XX:AOTCache=hw.aot  HelloWorld
```

Production run: use AOT cache for faster start-up, faster time to steady state

```
java -XX:AOTCache=hw.aot HelloWorld
```

### 2.1 JVM States Related to AOT Workflow


- [src/hotspot/share/cds/cdsConfig.hpp](https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/cds/cdsConfig.hpp)
- [src/hotspot/share/cds/cdsConfig.cpp](https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/cds/cdsConfig.cpp)


Frequently consulted states:

- `CDSConfig::is_dumping_archive()` - JVM can dump 4 types of archives depending on VM options: classic CDS static archive, classic CDS dynamic archive, AOT config file, AOT cache.
- `CDSConfig::is_using_archive()` - is the JVM loading data from at least one of the above 4 archives?


Advanced AOT optimizations introduced since [JEP 483](https://openjdk.org/jeps/483)

- `CDSConfig::is_dumping_aot_linked_classes()`
- `CDSConfig::is_dumping_invokedynamic()`
- `CDSConfig::is_dumping_method_handles()`
- `CDSConfig::is_dumping_aot_code()`
- `CDSConfig::is_dumping_adapters()`

## 3. Contents of AOT Cache

Note: both the AOT config file (result of the training run) and AOT cache (result of the assembly phase)
have the same "AOT archive" format -- a binary container that can store the following type of information.

- Class metadata ("runtime")
- Heap Objects ("gc")
- Method execution profile ("compiler")
- Compiled code ("compiler")

Differences between AOT config file and AOT cache:

- More heap objects are stored in the AOT cache
- Only AOT cache contains compiled code.
- AOT config file contains "recipes" for ahead-of-time linkage

Note: all discussion below about "AOT cache" also apply to the AOT config file when appropriate.

### 3.1 AOT Cache as JVM Snapshot

Conceptually, an AOT cache is a "clean" snapshot of the JVM at the end of the training run. The goals are:

- Avoid recreating the states (e.g. class metadata) from scratch (e.g., from JAR files).
- Avoid capturing environment dependencies that may not be reproducible in the production run. E.g.,

```
class MyApp {                                           // class metadata = aot-load
    static String date = LocalDate.now().toString();    // cannot cache (result of user code)!!!
    static void main(String args() {
        int x;
        Runnable r = () -> {                            // indy for lambda = aot-link
            x ^= date.hashCode();                       // invokevirtual = aot-link
            x >>= 1;
        };
        for (int i = 0; i < 1000000; i++) {             // hot loop = aot-compile
            r.run();
        }
        System.out.println(x);
    }
}
```

### 3.2 See what's inside the AOT cache

Add `-Xlog:aot+map=trace,aot+map+oops=trace:file=aot.map:none:filesize=0` to the assembly run or the production run.


Example: 1. Java Mirror of `java/lang/Boolean`

```
0x00000007ff856ef8: @@ Object (0xfff0addf) java.lang.Class Ljava/lang/Double; (aot-inited)
 - klass: 'java/lang/Class' 0x00000008000e4098
 - fields (26 words):
 - private volatile transient 'classRedefinedCount' 'I' @12  0 (0x00000000)
 - injected 'klass' 'J' @16  34360776008 (0x00000008000fd548)
 - injected 'array_klass' 'J' @24  0 (0x0000000000000000)
   [...]
 - signature:  Ljava/lang/Double; (aot-inited)
 - resolved_references: null- ---- static fields (1):
 - public static final 'POSITIVE_INFINITY' 'D' @128  inf (0x7ff0000000000000)
 - public static final 'NEGATIVE_INFINITY' 'D' @136  -inf (0xfff0000000000000)
   [...]
 - public static final 'TYPE' 'Ljava/lang/Class;' @120 0x00000007ff8a4578 (0xfff148af) java.lang.Class D
 - private static final 'serialVersionUID' 'J' @176  -9172774392245257468 (0x80b3c24a296bfb04)
```

Example: 2. The `java/lang/Double::TYPE` object

```
0x00000007ff8a4578: @@ Object (0xfff148af) java.lang.Class D
 - klass: 'java/lang/Class' 0x00000008000e4098
 - fields (15 words):
 - private volatile transient 'classRedefinedCount' 'I' @12  0 (0x00000000)
 - injected 'klass' 'J' @16  0 (0x0000000000000000)
 - injected 'array_klass' 'J' @24  34360604624 (0x00000008000d37d0)
   [...]
 - signature:  D
```

Example: 3. The `InstanceKlass` for `java/lang/Double`

```
0x00000008000fd548: @@ Class             648 java.lang.Double
0x00000008000fd548:   0000000800001080 0031000000000018 0000004000000000 0000000800331390   ..............1.....@.....3.....
0x00000008000fd568:   0000000000000000 00000008004fe4d8 00000008000d2558 00000008000fbda0   ..........O.....X%..............
0x00000008000fd588:   00000008000fd548 0000000000000000 0000000000000000 0000000000000000   H...............................
0x00000008000fd5a8:   0000000000000000 0000000000000000 000077f0f8123d20 00000008000fbda0   ................ =...w..........
0x00000008000fd5c8:   0000000000000000 00000008000fbb10 00000008000fbb10 000077f0f8103000   .........................0...w..
0x00000008000fd5e8:   0000000000000001 8000001100001000 0000004d00000018 ffffffff0000000b   ....................M...........
0x00000008000fd608:   0000000001ad0300 00000008004ff100 0000000800324dd8 0000000000000000   ..........O......M2.............
0x00000008000fd628:   00000008004fe590 0000000800462b30 000000080045b848 0000000000000000   ..O.....0+F.....H.E.............
0x00000008000fd648:   000000080045b848 0000000000000000 0000000000000000 0000000b00000003   H.E.............................
0x00000008000fd668:   0000000b00000000 0023000100010000 0000000008830001 0000000000000000   ..............#.................
0x00000008000fd688:   0000000000000000 0000000000000000 0000000000000000 0000000000000000   ................................
0x00000008000fd6a8:   0000000000000000 0000000000000000 0000000000000000 0000000000000000   ................................
0x00000008000fd6c8:   0000000000000000 0000000000000000 00000008004ff120 0000000000000000   ................ .O.............
0x00000008000fd6e8:   00000008004ffda0 00000008004ffdc0 0000000800462ca0 0000000000000000   ..O.......O......,F.............
0x00000008000fd708:   0000000800462d30 0000000000000000 0000000800005720 00000008000d2768   0-F............. W......h'......
0x00000008000fd728:   00000008000fd7d0 00000008000fd918 00000008000fd970 00000008000d28d8   ................p........(......
0x00000008000fd748:   00000008000fd9c8 00000008000fda20 00000008000fda78 00000008000fdad0   ........ .......x...............
0x00000008000fd768:   00000008000fdb28 00000008000fdb80 00000008000d6f60 0000000000000270   (...............`o......p.......
0x00000008000fd788:   00000008000d7640 0000000000000278 00000008000d78a8 0000000000000280   @v......x........x..............
0x00000008000fd7a8:   0000000000000000 0000000000000000 00000008000fe210 00000008000fe4b8   ................................
0x00000008000fd7c8:   00000008000fe408                                                      ........
```

Example: 4. The `Symbol` for `"java/lang/Double"`

```
0x0000000800331390: @@ Symbol            24 java/lang/Double
0x0000000800331390:   616a00100327ffff 2f676e616c2f6176 0000656c62756f44                    ..'...java/lang/Double..
```

## 4. Copying of Metadata into AOT Cache

- Prepare JVM states [AOTMetaspace::dump_static_archive_impl](https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/cds/aotMetaspace.cpp#L1080)

- Enter safepoint [VM_PopulateDumpSharedSpace](https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/cds/aotMetaspace.cpp#L1190)
  - [AOTArtifactFinder::find_artifacts()](https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/cds/aotArtifactFinder.cpp#L74): finds class metadata and oops that should be stored in the AOT cache.
    - Classes and oops are mutually dependent:
    - If an oop is stored, its class (and supers) must be stored
        - all reachable oops must also be stored
    - If a class is stored, its Java mirror must be stored
    - Some classes can be AOT-initialized: all oops in their static fields must be stored
    - Keep repeating the above until we reach a steady state


### 4.1 Class Metadata Discovery


- Class metadata for the AOT cache are copied recursively from a set of roots: [StaticArchiveBuilder::iterate_roots](https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/cds/aotMetaspace.cpp#L695)
- [MetaspaceClosure](https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.hpp) is used to traverse the pointers between metadata objects.
- All traversed objects are recursively copied
- C++ types that are supported by MetaspaceClosure have methods like this:

```
void Klass::metaspace_pointers_do(MetaspaceClosure* it) {
  it->push(&_name);              // points to a single Symbol* object
  it->push(&_secondary_supers);  // points to an Array<Klass*>
```

MetaspaceClosure is not easy to understand:

- It uses a lot of templates with `ENABLE_IF`
- To avoid overflowing the native stack, recursion is done using a side stack

To get a feel of how the templates are substituted, run `java -Xshare:dump` in `gdb` and
set breakpoints at `InstanceKlass::metaspace_pointers_do()` and `Method::metaspace_pointers_do()`.

For example, the following is how we traverse from a `Klass` object (#33) through
its `_secondary_supers` array (#26) to the `Klass` of one of its supers (#14)

<code>
#14 0x00007ffff6071fc7 in InstanceKlass::metaspace_pointers_do ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/oops/instanceKlass.cpp#L2652>hotspot/share/oops/instanceKlass.cpp:2652</a><br>
#15 0x00007ffff5842754 in MetaspaceClosure::MSORef<Klass>::metaspace_pointers_do ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.hpp#L224>hotspot/share/memory/metaspaceClosure.hpp:224</a><br>
#16 0x00007ffff652e94e in MetaspaceClosure::do_push ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.cpp#L79>hotspot/share/memory/metaspaceClosure.cpp:79</a><br>
#17 0x00007ffff652e77a in MetaspaceClosure::push_impl ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.cpp#L49>hotspot/share/memory/metaspaceClosure.cpp:49</a><br>
#18 0x00007ffff5841da3 in MetaspaceClosure::push_with_ref<MetaspaceClosure::MSORef<Klass>, Klass> ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.hpp#L428>hotspot/share/memory/metaspaceClosure.hpp:428</a><br>
#19 0x00007ffff584166f in MetaspaceClosure::push<Klass> ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.hpp#L458>hotspot/share/memory/metaspaceClosure.hpp:458</a><br>
#20 0x00007ffff5c6e8ab in MetaspaceClosure::MSOPointerArrayRef<Klass>::metaspace_pointers_do_at_impl ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.hpp#L299>hotspot/share/memory/metaspaceClosure.hpp:299</a><br>
#21 0x00007ffff5c6e472 in MetaspaceClosure::MSOPointerArrayRef<Klass>::metaspace_pointers_do ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.hpp#L292>hotspot/share/memory/metaspaceClosure.hpp:292</a><br>
#22 0x00007ffff652e94e in MetaspaceClosure::do_push ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.cpp#L79>hotspot/share/memory/metaspaceClosure.cpp:79</a><br>
#23 0x00007ffff652e77a in MetaspaceClosure::push_impl ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.cpp#L49>hotspot/share/memory/metaspaceClosure.cpp:49</a><br>
#24 0x00007ffff5c6da49 in MetaspaceClosure::push_with_ref<MetaspaceClosure::MSOPointerArrayRef<Klass>, Array<Klass*> > ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.hpp#L428>hotspot/share/memory/metaspaceClosure.hpp:428</a><br>
#25 0x00007ffff5c6d29d in MetaspaceClosure::push<Klass> ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.hpp#L475>hotspot/share/memory/metaspaceClosure.hpp:475</a><br>
#26 0x00007ffff63a99f4 in Klass::metaspace_pointers_do ()       // it->push(&_secondary_supers);<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/oops/klass.cpp#L762>hotspot/share/oops/klass.cpp:762</a><br>
#27 0x00007ffff6071fc7 in InstanceKlass::metaspace_pointers_do ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/oops/instanceKlass.cpp#L2652>hotspot/share/oops/instanceKlass.cpp:2652</a><br>
#28 0x00007ffff5842754 in MetaspaceClosure::MSORef<Klass>::metaspace_pointers_do ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.hpp#L224>hotspot/share/memory/metaspaceClosure.hpp:224</a><br>
#29 0x00007ffff652e94e in MetaspaceClosure::do_push ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.cpp#L79>hotspot/share/memory/metaspaceClosure.cpp:79</a><br>
#30 0x00007ffff652e77a in MetaspaceClosure::push_impl ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.cpp#L49>hotspot/share/memory/metaspaceClosure.cpp:49</a><br>
#31 0x00007ffff5841da3 in MetaspaceClosure::push_with_ref<MetaspaceClosure::MSORef<Klass>, Klass> ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.hpp#L428>hotspot/share/memory/metaspaceClosure.hpp:428</a><br>
#32 0x00007ffff584166f in MetaspaceClosure::push<Klass> ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/memory/metaspaceClosure.hpp#L458>hotspot/share/memory/metaspaceClosure.hpp:458</a><br>
#33 0x00007ffff583f86a in AOTArtifactFinder::all_cached_classes_do ()<br>
&nbsp;&nbsp;&nbsp;&nbsp;at <a href=https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/cds/aotArtifactFinder.cpp#L313>hotspot/share/cds/aotArtifactFinder.cpp:313</a><br>
&nbsp;&nbsp;&nbsp;&nbsp;// it->push(_all_cached_classes->adr_at(i)); (type = Klass**)
#34 0x00007ffff588bb18 in StaticArchiveBuilder::iterate_roots ( 
</code>

### 4.2 Class Exclusion

Uncachable classes are excluded from the AOT archive

- Classes that are redefined in training run
- JFR event classes (they *may* be processed by JFR using ClassFileLoadHook)
- Signed classes

A class is excluded if any of its dependencies are excluded

```
class A extends ExFoo implements ExBar {
    ExTaz get() {
        return new ExBam();  // If ExBam cannot be cast to ExTaz => VerifyError
    }
}
```

We basically need to recursively look at all of the super types (`ExBar` and `ExFoo`) as well
as all the types that are checked by the verifier (`ExTaz` and `ExBam`) to see if any of them is excluded.
If so, `A` also needs to be excluded.

However, the relation of these classes can become a cyclical graph, so a simple recursion may never end.
Instead, we use the algorithm described in [SystemDictionaryShared::check_exclusion_for_self_and_dependencies](https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/classfile/systemDictionaryShared.cpp#L343-L358)

## 5. AOT Constant Pool Resolution

- All constant pool entries that were resolved during the training run are recorded by
  [FinalImageRecipes::record_recipes_for_constantpool](https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/cds/finalImageRecipes.cpp#L52)
- These entries are resolved in the assembly phase by
  [FinalImageRecipes::apply_recipes]()https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/cds/finalImageRecipes.cpp#L225
- We only AOT-resolve entries that are checked to be OK [AOTConstantPoolResolver::is_resolution_deterministic()](https://github.com/openjdk/jdk/blob/ef2e5379f5290fd1d8a57c9e11544b03c86d1b3b/src/hotspot/share/cds/aotConstantPoolResolver.cpp#L44). E.g.,
   - Don't resolve Lambda expressions that uses an excluded interface
   - Don't resolve invokestatic whose callee's class is not AOT-initialized (see below).


### 5.1 AOT-linking of Invokedynamic

TBD

## 6. AOT Class Initialization

TBD

(Discussion of caching of the module graph ....)

## 7. Cross Reference between C++ and Java Objects

TBD

## 8. Class Preloading and Early Initialization in Production Run

TBD


