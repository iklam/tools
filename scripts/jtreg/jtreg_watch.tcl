set mydir [file dirname [info script]]
source $mydir/../lib/process_lib.tcl

if {[llength $argv] > 0} {
    set jdk [lindex $argv 0]
}

text .t -height 40
pack .t -expand yes -fill both

if {[info exists env(JTR_START)]} {
    set start $env(JTR_START)
} else {
    set start [clock seconds]
}
set last_update_ms [clock milliseconds]
set numpassed 0
set numfailed 0
set numerror  0
set numfinish 0
set has_started 0
set start_test_time $start
set end_test_time $start
set last_report_time 0
set has_parsed_java_files 0

set errors_len 0
proc print_compilation_error {file} {
    global errors_len env
    set max_err 20
    if {$errors_len >= $max_err} {
        return
    }
    set file [file tail $file]
    set file [file root $file]
    catch {
        set file [exec find $env(HOME)/tmp/$env(JTREG_DIR) -name $file.jtr | xargs ls -tr | tail -1]
    }
    if {[file exists $file]} {
        set fd [open $file]
        set data [read $fd]
        regsub -all {[-][-]direct:} $data \uffff data
        regsub .*\uffff $data \uffff data
        if {[regexp {\uffff([^\uffff]+) Compilation failed:} $data dummy error]} {
            regsub "^\[^\n\]*\n" $error "" error
            regsub {.result: Failed..*} $error "" error

            regsub "\n\[0-9\]+ warnings" $error "" error

            set nonln "\[^\n\]+"
            regsub -all "\n/${nonln}java:\[0-9\]+: warning: $nonln\(\n $nonln\)*" $error "" error

            puts ----------------------------------------------------------------------
            foreach line [split $error \n] {
                incr errors_len
                if {$errors_len == $max_err} {
                    puts ".... more errors"
                } elseif {$errors_len < $max_err} {
                    puts $line
                }
            }
            puts ----------------------------------------------------------------------
            
        }
        close $fd
    }
}

proc update_report {is_final_report} {
    global updating_report mydir non_final_report_done

    if {[info exists updating_report]} {
        set non_final_report_done 0
        if {$is_final_report} {
            while {[info exists updating_report]} {
                puts "waiting for non-final report to finish"
                vwait non_final_report_done
            }
            puts "non-final report has finished"
        } else {
            return
        }
    }

    #puts "Updating report"
    set updating_report 1
    set cmd "tclsh $mydir/jtreg_report.tcl"

    if {$is_final_report} {
        process_dispatch report $cmd
        process_join
        exit
    } else {
        process_dispatch report $cmd update_report_callback
    }
}

proc update_report_callback {handle output} {
    #puts $handle-$output-
    global updating_report last_report_time non_final_report_done

    if {$output != {}} {
        foreach line $output {
            puts $line
        }
    }
    set last_report_time [clock seconds]
    unset updating_report
    set non_final_report_done 1
}

proc doit {args} {
    global start numpassed numfailed numerror numfinish has_started start_test_time end_test_time running
    global failures last_test test_elapsed last_report_time has_parsed_java_files
    global updating_report final_report

    if {[info exists final_report]} {
        return
    }

    if {[eof stdin]} {
        if {[info exists failures]} {
            puts "\n\nFailures:"
            foreach line [lsort [array names failures]] {
                puts $line
                if {[regexp {Compilation failed} $line]} {
                    set file [lindex $line 0]
                    print_compilation_error $file
                }
            }
        }
        set final_report 1
        update_report 1
    }
    set line [gets stdin]
    set time [clock seconds]
    if {![info exists test_elapsed]} {
        set test_elapsed "     "
    }
    set skip 0

    if {$time - $last_report_time > 10 && ![info exists updating_report]} {
        update_report 0
    }

    if {[regexp {runner starting test: (.*)} $line dummy test]} {
        set running($test) $time
        if {$has_started == 0} {
            set test_elapsed [clock format [expr $time - $start] -format %M:%S]
            set has_started 1
            set start_test_time $time
        }
        regsub {runner starting test:} $line "  ...." line
        if {!$has_parsed_java_files} {
            set has_parsed_java_files 1
            set line ".... started ...."
        } else {
            set skip 1
        }
    } elseif {[regexp {runner finished test: (.*)} $line dummy test]} {
        set test_elapsed [clock format [expr $time - $running($test)] -format %M:%S]
        set last_test $test
        unset running($test)
        incr numfinish
        set skip 1
    } elseif {[regexp {^Passed.} $line]} {
        incr numpassed
        set line "  pass $last_test"
    } elseif {[regexp {^Failed.} $line]} {
        set line "$last_test\n    $line"
        set failures($line) 1
        incr numfailed
        set line "**FAIL $last_test"
    } elseif {[regexp {^Test results: } $line]} {
        set test_elapsed [clock format [expr $time - $start_test_time] -format %M:%S]
        set end_test_time $time
        regsub "Test results:" $line "===============>    Test results:  " line
        regsub failed: $line FAILED: line
        append line "      <============="
    } elseif {[regexp {^Results written } $line]} {
        set test_elapsed [clock format [expr $time - $end_test_time] -format %M:%S]
    }

    set numrun [llength [array size running]]
    set elapsed [clock format [expr $time - $start] -format %M:%S]
    if {!$skip} {
        puts [format {%s [%3d %3d %3d] %s %s} $elapsed $numfailed $numpassed $numfinish $test_elapsed $line]
        if {"$test_elapsed" != ""} {
            set test_elapsed "     "
        }
    }

    set_event
}

proc get_seconds {time} {
    if {[regexp {([0-9]+):([0-9]+)[.]([0-9]+)} $time dummy m s]} {
        #puts $time-$m-$s
        regsub ^0* $m "" m
        regsub ^0* $s "" s
        if {$m == ""}  {
            set m 0
        }
        if {$s == ""}  {
            set s 0
        }
        #puts $time-$m-$s
        return [expr $m * 60 + $s]
    } else {
        return 1
    }
}

set deadvms 0
set deadvmsec 0
proc updateit {} {
    global livevm deadvms deadvmsec savevm last_update_ms
    after 1000 updateit

    set time [clock seconds]
    set time_ms [clock milliseconds]
    global running jdk

    .t delete 1.0 end
    set total 0
    foreach test [lsort -dict [array names running]] {
        set elapsed [clock format [expr $time - $running($test)] -format %M:%S]
        .t insert end [format {%s %s%s} $elapsed $test \n]
        incr total
    }
    .t insert end "-- [format %3d $total] running test(s)"
    if {[info exists livevm]} {
        foreach pid [array names livevm] {
            set livevm($pid) 0
        }
    }

    set live_total_sec 0
    if {[info exists jdk]} {
        if 0 {
            set n 0
            catch {
                set n [exec ps -ef | grep jdk/bin/java | wc -l]
            }
            .t insert end "\n-- [format %3d $n] running jvm(s)"
        } else {
            set data ""
            catch {
                set data [exec top -n 2 -b -d 0.7]
                regsub {.*Tasks:} $data "" data
            }
            set free 0
            set used 0
            set buff 0
            set idle "  0.0"
            set wait "  0.0"
            set n    0
            
            regexp {([0-9]+) free} $data dummy free
            regexp {([0-9]+) used} $data dummy used
            regexp {([0-9]+) buff} $data dummy buff
            regexp {(.....) id,}   $data dummy idle
            regexp {(.....) wa,}   $data dummy wait

            foreach line [split $data \n] {
                regsub -all "\[ \t\]+" $line " " line
                regsub -all "^ " $line "" line
                set list [split $line " "]
                #puts "[lindex $list 0] [lindex $list 1] [lindex $list 11] $list" 
                if {[lindex $list 11] == "java"} {
                    incr n 1
                    set pid [lindex $list 0]
                    set sec [get_seconds [lindex $list 10]]
                    set livevm($pid) 1
                    set savevm($pid) $sec
                    incr live_total_sec $sec
                }
            }

            if {[info exists livevm]} {
                foreach pid [array names livevm] {
                    if {$livevm($pid) == 0} {
                        incr deadvms
                        incr deadvmsec $savevm($pid)
                        unset livevm($pid)
                        unset savevm($pid)
                    }
                }
            }

            set target_idle [expr 100.0 * (32 - $total) / 32.0]
            set idle_info ""
            set fuss 10.0
            if {$idle - $fuss > $target_idle} {
                set idle_info "  *** UNDER-utilize [format %4.2f%% [expr $idle - $target_idle]]"
            } elseif {($idle + $fuss) < $target_idle} {
                set idle_info "       over-utilize [format %4.2f%% [expr $target_idle - $idle]]"
            }

            .t insert end "\n-- [format %3d $n      ] running jvms [format %6d $live_total_sec] sec"
            .t insert end "\n-- [format %3d $deadvms] dead jvms    [format %6d $deadvmsec     ] sec"
            .t insert end "\n-- [format %9s $idle] idle$idle_info"
            .t insert end "\n-- [format %9s $wait] wait"
            .t insert end "\n-- [format %9d $used] used"
            .t insert end "\n-- [format %9d $free] free"
            .t insert end "\n-- [format %9d $buff] buff"
            .t insert end "\n-- [format %9d [expr $time_ms - $last_update_ms]] update"
            set last_update_ms $time_ms
        }
    }
    update idletasks
}

proc set_event {} {
    fileevent stdin readable doit
}
set_event
after 1000 updateit
vwait forever
