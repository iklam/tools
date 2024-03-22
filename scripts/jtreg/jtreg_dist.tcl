# jtreg_dist.tcl --
#
# My harness to distribute jtreg tests across several workstations for higher throughput
# Similar to ../myide/distcc.tcl
#
# Use the dispatch server implemented in ../myide/autoraise.tcl (port 9988).
proc findtests {} {
    global argv env
    set cmd {}
    foreach arg $argv {
        if {[regexp {^[-][JDe]} $arg]} {
            continue
        }
        if {[regexp {^[-]((conc)|(verbose)|(timeout)|(agentvm)|(vmoptions)|(nativepath))} $arg]} {
            continue
        }
        lappend cmd $arg
        if {[llength $cmd] == 1} {
            # list all test cases
            lappend cmd -l
        }
    }

    regsub -all {(/bld/[^/]+)-[^/]+(/images/jdk)} $cmd "\\1\\2" cmd

    set cmd1 $cmd
    set cmd2 $cmd

    set pat {(/jtreg[^/]*)/work}
    regsub $pat $cmd1 "\\1/list" cmd1
    regsub $pat $cmd2 "\\1/list-multi" cmd2

    #puts $cmd1
    #puts $cmd2

    if {[catch {set data [eval exec $cmd1]}]} {
        set data [eval exec $cmd2]
    }

    set suite {}
    foreach line [split $data \n] {
        set line [string trim $line]
        if {[regexp {Testsuite: (.*)} $line dummy suite]} {
            continue
        }
        if {[regexp {ests found:} $line]} {
            continue
        }
        if {"$line" == ""} {
            continue
        }
        lappend tests [list $suite $line]
    }
    return $tests
}


set tests [findtests]

foreach x $tests {
    puts $x
}

exit

puts {
runner starting test: runtime/cds/appcds/HelloTest.java
runner finished test: runtime/cds/appcds/HelloTest.java
Passed. Execution successful
Test results: passed: 1
Results written to /var/www/html/jtreg2/work
}
