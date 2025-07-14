# jtreg_dist.tcl --
#
# My harness to distribute jtreg tests across several workstations for higher throughput
# Similar to ../myide/distcc.tcl
#
# Use the dispatch server implemented in ../myide/autoraise.tcl (port 9988).

set script_dir [file dirname [info script]]

proc findtests {} {
    global argv env

    set cmd {}
    foreach arg $argv {
        if {[regexp {^[-][JD]} $arg]} {
            continue
        }
        if {[regexp {^[-][e]:} $arg]} {
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
        if {[regexp SpringPetClinic $line]} {
            continue
        }
        lappend tests [list $suite $line]
    }

    if {![info exists tests]} {
        puts "Test results: no tests selected"
        exit 1
    }

    return $tests
}


# Get all jtreg command options, but stop when we see "-w".
# My _jtrxxx script put the names of test files/dirs after -w, so this
# effectively skips all the test cases, whcih we have already found with [filetests]
proc jtreg_main_params {} {
    global argv

    set main_params ""
    foreach arg $argv {
        if {[regexp {^[-]((conc)|(verbose)|(retain))} $arg]} {
            continue
        }
        if {"$arg" == "-w"} {
            break;
        }
        lappend main_params $arg
    }

    return $main_params
}

proc main {} {
    global env pending_tests main_params waiting_host num_passes num_failures num_errors storedir
    set pending_tests [findtests]
    set main_params [jtreg_main_params]
    set storedir /jdk3/tmp/$env(JTREG_DIR)/work

    foreach t $pending_tests {
        #puts $t
    }

    set waiting_host 0
    set num_passes 0
    set num_failures 0
    set num_errors 0
    start_one_test

    vwait forever
}

proc start_one_test {} {
    global pending_tests waiting_host

    if {[llength $pending_tests] > 0} {
        set testspec [lindex $pending_tests 0]
        set pending_tests [lrange $pending_tests 1 end]
        set fd [socket localhost 9989]

        # Each jtreg test needs about 1.3 CPU (temporary number ... needs tweaking)
        puts $fd 180
        puts $fd $testspec
        flush $fd
        set waiting_host 1
        fileevent $fd readable [list launch_test $fd $testspec]
    }

    check_for_exit
}

proc launch_test {fd testspec} {
    global waiting_host main_params env script_dir storedir running_tests setup_host

    set host [gets $fd]
    set slot [gets $fd]
    #set host ioimac

    if {$host != "localhost" && ![info exists setup_host($host)]} {
        set setup_host($host) 1
        exec ssh $host mkdir -p $env(JIB_HOME)
        exec rsync -e ssh -av $env(JIB_HOME)/ $env(USER)@$host:$env(JIB_HOME)/ >@ stdout 2>@ stdout
    }

    set dir  [lindex $testspec 0]
    set test [lindex $testspec 1]

    #puts stderr $host==$slot==$test
    puts "runner starting test: $test"

    set workdir /tmp/$env(USER)/$env(JTREG_DIR)/$slot/work
    # FIXME - use a local version of java ??
    # FIXME - use a local version of jtreg ??
    set cmd "|bash $script_dir/jtreg_dist_exec0.sh ssh $host bash $script_dir/jtreg_dist_exec.sh $env(JAVA_HOME) $dir $workdir $storedir"
    foreach m $main_params {
        regsub -all " " $m {\\\\ } m
        append cmd " $m"
    }

    append cmd " -w $workdir"
    append cmd " -retain:all"
    append cmd " $test"

    #puts $cmd
    #puts ==============================

    #regsub -all /jdk3/official/ $cmd /tmp/$env(USER)/ cmd
    #regsub -all /jdk3/bld/le5/ $cmd /tmp/$env(USER)/le5/ cmd
    #regsub -all /jdk3/le5/ $cmd /tmp/$env(USER)/repo/le5/ cmd

    set fd2 [open $cmd r]
    fileevent $fd2 readable [list monitor_test $fd $fd2 $test]
    set running_tests($test) 1

    # Note: we launch one test at a time, never in parallel.
    # This is for fairness with other terminals that may run "jtrxxxp" at the same time.
    set waiting_host 0
    start_one_test
    check_for_exit
}

proc monitor_test {fd fd2 test} {
    global test_output running_tests num_passes num_failures num_errors waiting_host pending_tests

    # Read one line at a time until all output is read.
    # This is OK because each test has very few lines of output
    if {![eof $fd2]} {
        append test_output($test) "[gets $fd2]\n"
        fileevent $fd2 readable [list monitor_test $fd $fd2 $test]
        return
    }
    close $fd
    close $fd2

    puts "runner finished test: $test"

    set out $test_output($test)
    if {[regexp "Failed. \[^\n\]*" $out found]} {
        puts $found
        incr num_failures 1
    } elseif {[regexp "Error. \[^\n\]*" $out found]} {
        puts $found
        incr num_errors 1
    } else {
        puts "Passed. Execution successful"
        incr num_passes 1
    }

    puts ------------------------------
    puts $out
    puts ------------------------------

    unset test_output($test)
    unset running_tests($test)

    #puts "[llength $pending_tests] $waiting_host"
    if {$waiting_host == 0} {
        start_one_test
    }
    check_for_exit
}

proc check_for_exit {} {
    global pending_tests waiting_host running_tests num_passes num_failures num_errors storedir

    set num_running 0
    if {[info exists running_tests]} {
        set num_running [array size running_tests]
    }

    #puts "check_for_exit [llength $pending_tests] $num_running $waiting_host"

    if {[llength $pending_tests] == 0 &&
        $num_running == 0 &&
        $waiting_host == 0} {

        puts "Test results: passed: $num_passes; failed $num_failures; error: $num_errors"
        puts "Results written to $storedir"
        set code [expr $num_failures + $num_errors]
        if {$code > 0} {
            puts "Error: Some tests failed or other problems occurred."
        }
        exit $code
    }
}

main
