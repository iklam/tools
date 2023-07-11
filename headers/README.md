# Scripts for Optimizing HotSpot Header Files

This folder has a few script for diagnosing problems with header file inclusion. 

The build time of HotSpot tends to be dominated by C++ header file inclusion. Over the past few years,
I removed many unnecessary includes to reduce the HotSpot build time (See [this list of
JBS issues](https://bugs.openjdk.org/issues/?jql=labels%20in%20(headers%2C%20include%2C%20includes)%20and%20component%20%3D%20hotspot)). 
I found these script very useful.

**This page is just an overview. Please see the script themselves for usage details.**

## [count_hotspot_headers_diff.tcl](count_hotspot_headers_diff.tcl)


This script counts how many times each header file is included in the HotSpot build.

For example, if a relatively obscured header file is included a lot of time (like generateOopMap.hpp in
[JDK-8310225](https://bugs.openjdk.org/browse/JDK-8310225)), this usually indicates a problem of unnecessary inclusion.

The output looks like this:

```
$ tclsh count_hotspot_headers.tcl | sort -n | tail -10

    +----------------- (A x B) -- this is roughly "how much time does gcc spend on compiling os.hpp"
    |
    |        +-------- (A) os.hpp was included by 934 .o files
    |        |    +--- (B) os.hpp has 1019 lines
    v        v    v    
  951746    934  1019 /jdk2/gil/open/src/hotspot/share/runtime/os.hpp
 1112670     65 17118 /home/iklam/jdk/bld/gil-debug/hotspot/variant-server/gensrc/jfrfiles/jfrEventClasses.hpp
 1204728    994  1212 /jdk2/gil/open/src/hotspot/share/utilities/globalDefinitions.hpp
 1359039     33 41183 /home/iklam/jdk/bld/gil-debug/hotspot/variant-server/gensrc/adfiles/ad_x86.hpp
 1687752    792  2131 /jdk2/gil/open/src/hotspot/share/runtime/thread.hpp
 1938300    923  2100 /jdk2/gil/open/src/hotspot/share/runtime/globals.hpp
 1975078    994  1987 /home/iklam/jdk/bld/gil-debug/support/modules_include/java.base/jni.h
99999999 ======================================================================
99999999 total_count = 231452    <-- Sum of (A)
99999999 total_lines = 58605456  <-- Sum of (A x B) 
```

The last two lines show the total impact of header files. The "total_lines" number
is "how many lines of header files have been compiled during the entire HotSpot build".

Unfortunately this number has steady grown over the past few releases. It was at about 71,601,952 for JDK 20 and has grown to about 96,714,013 (96 million lines!) in JDK 21.

## [whoincludes.tcl](whoincludes.tcl)

When count_hotspot_headers.tcl shows a file with a suspiciously high number of inclusion, it's usually because this
header was unnecessarily included by other header files. This can be diagnosed with [whoincludes.tcl](whoincludes.tcl).

For example, in [JDK-8310225](https://bugs.openjdk.org/browse/JDK-8310225), after seeing a suspicously
high number of generateOopMap.hpp in the output of count_hotspot_headers_diff.tcl, I ran this to find out who
included it:


```
/repo/jdk-cpu/open/src/hotspot$ alias wi='tclsh /repo/tools/headers/whoincludes.tcl'
/repo/jdk-cpu/open/src/hotspot$ wi generateOopMap.hpp
scanning    537 generateOopMap.hpp
   2 found    526 oopMapCache.hpp
   3 found     17 parse.hpp
/repo/jdk-cpu/open/src/hotspot$ wi oopMapCache.hpp
scanning    526 oopMapCache.hpp
   2 found    526 frame_x86.inline.hpp
   3 found      6 stackChunkFrameStream_x86.inline.hpp
   4 found      5 continuationHelper.inline.hpp
   5 found      0 stackChunkFrameStream_zero.inline.hpp
   6 found      0 stackChunkFrameStream_ppc.inline.hpp
   7 found      0 frame_riscv.inline.hpp
   8 found      0 stackChunkFrameStream_riscv.inline.hpp
   9 found      0 frame_aarch64.inline.hpp
  10 found      0 stackChunkFrameStream_aarch64.inline.hpp
  11 found      0 stackChunkFrameStream_arm.inline.hpp
  12 found      0 stackChunkFrameStream_s390.inline.hpp
```

These inclusions are unnecessary, so they are removed in the [fix](https://github.com/openjdk/jdk/commit/28415adb795dd9d4905d2366c6cc88fc569b8f80).

# [count_hotspot_headers.tcl](count_hotspot_headers.tcl)

Use this script to find out how the number of inclusion has changed between two JDK builds. For example, comparing JDK 20 and 21, we get this:

```
  1152 (     0 ->   1152) src/hotspot/share/utilities/attributeNoreturn.hpp
  1081 (     0 ->   1081) src/hotspot/share/utilities/byteswap.hpp
   917 (     0 ->    917) src/hotspot/share/runtime/lockStack.hpp
   807 (     0 ->    807) src/hotspot/share/oops/resolvedIndyEntry.hpp
   807 (     0 ->    807) src/hotspot/share/oops/constMethodFlags.hpp
  [...]
   572 (     0 ->    572) src/hotspot/share/gc/z/zGeneration.hpp
   571 (    42 ->    613) src/hotspot/share/gc/z/zLock.hpp
```

Some of those are normal (attributeNoreturn.hpp was added in JDK 21 due to code refactoring, so it didn't exist in JDK 20).

However, zLock.hpp was included only 42 times in JDK 20 but inreased to 613 times in JDK 21, so that's something worth investigating.

