# bench_all.tcl
#
#    Compare CDS performance across versions of JDK
#
# Usage:
#     tclsh bench_all.tcl /path/to/jdks <scale> <vm options ...>
#
#     By default, scale is 100
#
# Example:
#
#     tclsh bench_all.tcl /path/to/jdks 100
#     tclsh bench_all.tcl /path/to/jdks 100 -XX:+UseSerialGC
#

set jdks {
    jdk-8u40
    jdk-11
    jdk-17
    jdk-19
}

set heapsize {
    -Xmx256m
}

proc selected_benchmarks {} {
    global env

    if {[info exists env(RUNONLY)]} {
        return $env(RUNONLY)
    } else {
        return {helloworld javac}
    }
}

proc usage {msg} {
    puts "Error: $msg\n"
    puts "Usage: tclsh bench_all.tcl /path/to/jdks <scale> <vm options ...>"
    puts "By default, scale is 100"
    exit 1
}

proc setup {} {
    global argv jdks root scale javac jar cwd outdir moreargs
    set root  [lindex $argv 0]
    set scale [lindex $argv 1]
    set moreargs [lrange $argv 2 end]

    foreach jdk $jdks {
        if {![file exists $root/$jdk/bin/javac]} {
            usage "$root/$jdk/bin/javac doesn't exist"
        }
    }

    set cwd [pwd]
    set javac $root/jdk-8u40/bin/javac
    set jar   $root/jdk-8u40/bin/jar

    set outdir $cwd/out
    file mkdir $outdir
}

proc do_exec {args} {
    puts "Exec: $args"
    if {[regexp > $args]} {
        eval exec $args
    } else {
        eval exec $args >@ stdout 2>@ stderr
    }
}

proc get_vmargs {type jdk appname jar mainclass vmargs} {
    global root outdir heapsize moreargs env

    set vmargs [concat $heapsize $vmargs]

    if {"$jar" != ""} {
        lappend vmargs -cp $jar
    }
    if {"$jdk" == "jdk-8u40"} {
        lappend vmargs -XX:+UnlockCommercialFeatures -XX:+UseAppCDS
    }


    set classlist $outdir/$appname.$jdk.classlist
    set archiveopt -XX:SharedArchiveFile=$outdir/$appname.$jdk.jsa

    if {$type == "trial"} {
        lappend vmargs -Xshare:off -XX:DumpLoadedClassList=$classlist
        if {$mainclass != ""} {
            lappend vmargs $mainclass
        }
    } elseif {$type == "dump"} {
        lappend vmargs -Xshare:dump -XX:SharedClassListFile=$classlist $archiveopt
    } else {
        if {[info exists env(DEFCDS)]} {
            # Let the JDK use the default archive
        } else {
            lappend vmargs -Xshare:on $archiveopt
        }

        if {[info exists env(SERIALGC)]} {
            lappend vmargs -XX:+UseSerialGC
        }
        if {$moreargs != ""} {
            eval lappend vmargs $moreargs
        }
        if {$mainclass != ""} {
            lappend vmargs $mainclass
        }
    }


    return $vmargs
}

proc get_tool_vmargs {type jdk appname jar mainclass vmargs} {
    set vmargs [get_vmargs $type $jdk $appname $jar $mainclass $vmargs]

    set args {}
    foreach a $vmargs {
        lappend args "-J$a"
    }

    return $args
}

proc run_java {type jdk appname jar mainclass args} {
    global root
    set vmargs [get_vmargs $type $jdk $appname $jar $mainclass $args]

    eval do_exec $root/$jdk/bin/java $vmargs
}

proc run_javac {type jdk appname jar mainclass args} {
    global root
    set vmargs [get_tool_vmargs $type $jdk $appname $jar $mainclass $args]

    eval do_exec $root/$jdk/bin/javac $vmargs HelloWorld.java
}

proc build_helloworld {} {
    global cwd javac jar outdir jdks

    cd $cwd
    if {![file exists $outdir/HelloWorld.jar]} {
        file mkdir $outdir/HelloWorld.classes
        do_exec $javac -d $outdir/HelloWorld.classes HelloWorld.java 
        do_exec $jar cvf0 $outdir/HelloWorld.jar -C $outdir/HelloWorld.classes .
    }

    foreach jdk $jdks {
        cd $cwd
        if {[file exists $outdir/HelloWorld.$jdk.jsa]} {
            continue
        }

        run_java trial $jdk HelloWorld $outdir/HelloWorld.jar HelloWorld
        run_java dump  $jdk HelloWorld $outdir/HelloWorld.jar HelloWorld

        # Just run it once to make sure the archive works
        run_java run   $jdk HelloWorld $outdir/HelloWorld.jar HelloWorld
    }
}

proc build_javac {} {
    # No need to build any JAR files, but need to build JSA files
    global jdks cwd outdir

    foreach jdk $jdks {
        cd $cwd
        if {[file exists $outdir/javac.$jdk.jsa]} {
            continue
        }

        run_javac trial $jdk javac "" ""
        run_javac dump  $jdk javac "" ""

        # Just run it once to make sure the archive works
        run_javac run   $jdk javac "" ""
    }

}

proc build {} {
    foreach bench [selected_benchmarks] {
        build_$bench
    }
}

proc bench_helloworld {i} {
    global cwd outdir jdks root scale

    set repeat [expr int(40 * $scale / 100)]
    if {$repeat < 1} {
        set repeat 1
    }
    foreach jdk $jdks {
        set datadir $outdir/helloworld-$jdk
        file mkdir $datadir
        set num [format %03d $i]
        set vmargs [get_vmargs run $jdk HelloWorld $outdir/HelloWorld.jar HelloWorld ""]
        eval do_exec perf stat -r $repeat $root/$jdk/bin/java $vmargs \
            > $datadir/stdout.$num 2> $datadir/perf.$num
    }
}

proc bench_javac {i} {
    global cwd outdir jdks root scale

    set repeat [expr int(5 * $scale / 100)]
    if {$repeat < 1} {
        set repeat 1
    }
    foreach jdk $jdks {
        set datadir $outdir/javac-$jdk
        file mkdir $datadir
        set num [format %03d $i]
        set vmargs [get_tool_vmargs run $jdk javac "" "" ""]
        eval do_exec perf stat -r $repeat $root/$jdk/bin/javac $vmargs HelloWorld.java \
            > $datadir/stdout.$num 2> $datadir/perf.$num
    }
}

proc run {} {
    global scale jdks outdir env

    if {[info exists env(NORUN)]} {
        # Use this to just calculate the scores
        return
    }

    foreach jdk $jdks {
        set datadir $outdir/helloworld-$jdk
        file delete -force $datadir
    }

    set outerloop 10
    if {$scale <= 10} {
        set outerloop 1
        set scale [expr $scale * 10]
    } elseif {$scale <= 20} {
        set outerloop 2
        set scale [expr $scale * 5]
    } elseif {$scale <= 50} {
        set outerloop 5
        set scale [expr $scale * 2]
    }
    if {$scale < 1} {
        set scale 1
    }


    foreach bench [selected_benchmarks] {
        for {set i 1} {$i <= $outerloop} {incr i} {
            bench_$bench $i
        }
    }
}

proc geomean {list} {
    expr pow([join $list *],1./[llength $list])
}

proc do_score {bench} {
    global scale jdks outdir

    set max 0
    foreach jdk $jdks {
        puts -nonewline [format %10s%11s $jdk ""]
        set datadir $outdir/$bench-$jdk
        set list-$jdk {}
        set error-$jdk {}

        set n 0
        foreach f [lsort [glob $datadir/perf.*]] {
            set fd [open $f]
            set data [read $fd]
            if {[regexp {([0-9.]+) .. ([0-9.]+) seconds time elapsed} $data dummy elapsed error]} {
                # good
            } elseif {[regexp {([0-9.]+) seconds time elapsed} $data dummy elapsed]} {
                set error 0
            } else {
                puts "Bad perf data file $f??"
                puts $data
                exit 1
            }
            lappend list-$jdk $elapsed
            lappend error-$jdk $error

            incr n
            if {$max < $n} {
                set max $n
            }
        }
    }
    puts ""
    for {set i 0} {$i < $max} {incr i} {
        foreach jdk $jdks {
            set list [set list-$jdk]
            set n [lindex $list $i]
            if {$n == ""} {
                puts -nonewline [format %10s -]
            } else {
                set n [expr $n * 1000]
                puts -nonewline [format %10.3f $n]
            }
            set list [set error-$jdk]
            set n [lindex $list $i]
            if {$n == ""} {
                puts -nonewline [format %11s -]
            } else {
                set n [expr $n * 1000]
                puts -nonewline [format %11s \u00b1[format %.3f $n]]
            }
        }
        puts ""
    }

    foreach jdk $jdks {
        puts -nonewline ---------------------
    }
    puts ""

    foreach jdk $jdks {
        set n [expr [geomean [set list-$jdk]] * 1000]
        puts -nonewline [format %10.3f%11s $n ""]
    }
    puts ""
}

proc score {} {
    foreach bench [selected_benchmarks] {
        puts ------------------------------------------------------------------------------------
        puts "Scores for $bench $moreargs"
        puts ------------------------------------------------------------------------------------

        do_score $bench
    }
}

proc main {} {
    setup
    build
    run
    score
}

main
