# whoincludes.tcl -- find out "why is this header included so many times"
#
# version 1.0
#
# Example
# $ export MYJDK=/my/jdk/build/dir/images/jdk
# $ cd /my/repo/open/src/hotspot
#
# (1) Which header files directly include jvm.h:
#
# $ tclsh whoincludes.tcl jvm.h
#   scanning    926 jvm.h          <--- jvm.h is included by 926 .o files
#      2 found    923 os.hpp       <--- os.hpp includes jvm.h, and os.hpp is included by 923 .o files
#      3 found    810 accessFlags.hpp
#      4 found    810 constantTag.hpp
#      5 found    488 formatBuffer.hpp
#      6 found    271 ciFlags.hpp
#
# (2) Find all header files that have directly or indirectly included jvm.h
#
# $ tclsh whoincludes.tcl -r jvm.h
# (tons of output .....)
#
# $ tclsh whoincludes.tcl -r 2 jvm.h
# (limit to 2 levels of checking)

if {![info exists env(MYJDK)]} {
    # Ioi's own setting.
    catch {set env(MYJDK) $env(TESTBED)}
}

if {![info exists env(MYJDK)] || ![file isdir $env(MYJDK)/../../hotspot]} {
    puts "Error:"
    puts "    Please set the env variabe MYJDK to point to the images/jdk directory of your JDK build"
    puts "    This script assumes that your HotSpot object files are under \$MYJDK/../../hotspot"
    exit 1
}

if {![file exists share/prims/jvm.cpp]} {
    puts "Warning: "
    puts "    Please run this script under the src/hotspot directory of your OpenJDK repo"
}

set maxdepth 1
if {[lindex $argv 0] == "-r"} {
    if {[catch {
        set maxdepth [expr [lindex $argv 1] + 0]
        set argv [lrange $argv 2 end]
    }]} {
        set maxdepth 100000
        set argv [lrange $argv 1 end]
    }
}

set header [lindex $argv 0]
set list $header
set length [llength $list]

proc included_count {file} {
    global env seen

    if {[info exists seen($file)]} {
        return $seen($file)
    }

    set dir [file dir [file dir $env(MYJDK)]]
    set count 0
    catch {
        set count [exec find $dir/hotspot -name \*.d | xargs grep -l /$file | wc -l]
    }

    set seen($file) $count
    return $count
}

set found(precompiled.hpp) 1

proc mycomp {a b} {
    return [expr [lindex $b 1] - [lindex $a 1]]
}

while 1 {
    set hasnew 0
    foreach file $list {
        if {![info exists found($file)]} {
            puts "scanning [format %6d [included_count $file]] $file"
            set found($file) 1
            set lines {}
            if {[catch {
                set pat "^#include.*\[\"/\]$file"
                set lines [exec find . -name \*.hpp -print -o -name \*.h -print | xargs grep -l $pat ]
                #puts $pat
                #puts $lines
            }]} {
                #puts "???? no one includes $file"
            }

            set tmp {}
            set progress 0
            foreach line $lines {
                incr progress
                regsub .*/ $line "" line
                if {![info exists found($line)]} {
                    lappend tmp [list $line [included_count $line]]
                }
                if {$progress % 30 == 0} {
                    puts -nonewline stderr .
                }
            }
            if {$progress > 30} {
                catch {puts stderr ""}
            }
            foreach item [lsort -command mycomp $tmp] {
                set f [lindex $item 0]
                set c [lindex $item 1]
                lappend list $f
                catch {puts "[format %4d [llength $list]] found [format %6d $c] $f"}
                set hasnew 1
            }
        }
    }
    if {!$hasnew} {
        break
    }
    incr maxdepth -1
    if {$maxdepth > 0} {
       #puts "cont ... $maxdepth"
        puts "cont ... "
    } else {
        break;
    }
}



