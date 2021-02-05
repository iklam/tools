# count_hotspot_headers.tcl --
#
# Count how many times each header file is included in the HotSpot build. You can use this
# script to find .hpp files for refactoring in order to reduce the amount
# of included headers in the HotSpot build.
#
# You should run this script inside your JDK build directory. It assumes that you
# are building the "server" variant.
# 
# Example 1: hwo to use this script
#
# $ tclsh count_hotspot_headers.tcl | sort -n | tail -10
#
#     +----------------- (A x B) -- this is roughly "how much time does gcc spend on compiling os.hpp"
#     |
#     |        +-------- (A) os.hpp was included by 934 .o files
#     |        |    +--- (B) os.hpp has 1019 lines
#     v        v    v    
#   951746    934  1019 /jdk2/gil/open/src/hotspot/share/runtime/os.hpp
#  1112670     65 17118 /home/iklam/jdk/bld/gil-debug/hotspot/variant-server/gensrc/jfrfiles/jfrEventClasses.hpp
#  1204728    994  1212 /jdk2/gil/open/src/hotspot/share/utilities/globalDefinitions.hpp
#  1359039     33 41183 /home/iklam/jdk/bld/gil-debug/hotspot/variant-server/gensrc/adfiles/ad_x86.hpp
#  1687752    792  2131 /jdk2/gil/open/src/hotspot/share/runtime/thread.hpp
#  1938300    923  2100 /jdk2/gil/open/src/hotspot/share/runtime/globals.hpp
#  1975078    994  1987 /home/iklam/jdk/bld/gil-debug/support/modules_include/java.base/jni.h
# 99999999 ======================================================================
# 99999999 total_count = 231452    <-- Sum of (A)
# 99999999 total_lines = 58605456  <-- Sum of (A x B) 
#
# The goal is to reduce total_lines. In Sep 2020 this was over 70000000, so we have gotten it
# down to 58605456 in early Feb 2021.
#
# Example 2: how to find a header to fix
#
# $ tclsh /jdk2/tools/headers/count_hotspot_headers.tcl | sort -n | grep classLoaderData.hpp
#  233495    697   335 /jdk2/gil/open/src/hotspot/share/classfile/classLoaderData.hpp
#
# We'd assume not many parts of HotSpot are using ClassLoaderData -- most of GC and JIT
# would shouldn't care about ClassLoaderData. So why is it included so many times (697
# out of about 1000 .o file)? We can find out using whoincludes.tcl
#
# $ cd src/hotspot
# $ whoincludes classLoaderData.hpp
# scanning    698 classLoaderData.hpp
#    2 found    695 klass.hpp                  <---- refactoring candidate
#    3 found    650 typeArrayKlass.hpp         <---- refactoring candidate
#    4 found    647 instanceKlass.hpp          <---- refactoring candidate
#    5 found    138 classLoaderData.inline.hpp
#    6 found    124 moduleEntry.hpp
#    7 found    109 objArrayKlass.hpp
#    8 found     92 jfrTraceIdLoadBarrier.inline.hpp
#    9 found     54 classLoaderDataGraph.hpp
#   10 found     43 iterator.inline.hpp
#   11 found     24 metadataFactory.hpp
#   12 found      4 classLoaderStats.hpp
#   13 found      3 fieldLayoutBuilder.hpp
#
# Hmmm, it looks like if we can refactor the top 3 headers to get rid of their dependency on
# classLoaderData.hpp, we can significantly reduce the number of files that include
# classLoaderData.hpp.

set dir hotspot/variant-server/libjvm/objs

if {![file exists hotspot/variant-server/libjvm/objs]} {
    puts "Error:"
    puts "    Please run this script in your JDK build directory."
    puts "    This script assumes that you have the directory ./$dir"
    exit 1
}


set n 0
foreach file [glob $dir/*.d] {
    if {[regexp BUILD_LIBJVM $file]} {
        continue
    }
    catch {unset seen}
    set fd [open $file]
    while {![eof $fd]} {
        set line [gets $fd]
        if {[regexp {[.]h} $line]} {
            set line [string trim $line]
            regsub { .*} $line "" line
            if {![info exists seen($line)]} {
                incr count($line)
                set seen($line) 1
            }
        }
    }
    close $fd
    incr n
    if {$n > 100000} {
        break
    }
}

proc foo {a b} {
    global count
    if {$count($a) > $count($b)} {
        return -1
    } elseif {$count($a) == $count($b)} {
        return 0
    } else {
        return 1
    }
}

foreach name [lsort -command foo [array names count]] {
    set lines [string trim [exec wc -l $name]]
    regsub " .*" $lines "" lines
    set impact [expr $count($name) * $lines]
    puts [format {%8d %6d %5d %s} $impact $count($name) $lines $name]
    incr total_count $count($name)
    incr total_lines $impact
}

puts "99999999 ======================================================================"
puts "99999999 total_count = $total_count"
puts "99999999 total_lines = $total_lines"


