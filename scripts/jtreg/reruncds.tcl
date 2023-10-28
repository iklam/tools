# Usage
#     reruncds.tcl <jtrfile> <which> <jvm> <preopts ...> <--> <postopts ...>
#     The first of <preopts> may be "-gdb" or "-gdbauto"
#
# example:
#
# reruncds LWorld
# reruncds LWorld 2
# reruncds LWorld 2 d
# reruncds LWorld 2 d -gdb -verbose
# reruncds LWorld 2 fd -gdb -- -Xint

file delete -force /tmp/reruncds.sh

proc quote {w} {
    if {![regexp ' $w] && [regexp {[*<> ]} $w]} {
        set w \'$w\'
    }
    if {[regexp "^ {(.*)}" $w dummy x]} {
        set w $x
    }
    return $w
}

proc append_cmd {x} {
    global cmd_list
    lappend cmd_list $x
}

proc append_for_bash {fd w} {
    global bash_prefix
    set w [quote $w]
    puts -nonewline $fd $bash_prefix$w
    set bash_prefix " \\\n    "
}

proc clean_cmd_list {} {
    global cmd_list
    set dontskip 1
    set len [llength $cmd_list]
    set new_list {}
    for {set i [expr $len - 1]} {$i >= 0} {incr i -1} {
        set x [lindex $cmd_list $i]
        if {"$x" == "-Xlog:cds=debug,class+load,class+loader+constraints"} {
            set x "-Xlog:cds"
        }
        if {"$x" == "-Xlog:class+load,cds+dynamic=info,cds"} {
            set x "-Xlog:cds"
        }
        if {"$x" == "-Xlog:class+load,cds=debug"} {
            set x "-Xlog:cds=debug"
        }
        if {"$x" == "-Xlog:class+load,cds"} {
            set x "-Xlog:cds"
        }
        if {"$x" == "-Xlog:class+load"} {
            continue
        }
        if {"$x" == "-Xlog:class+load=debug"} {
            continue
        }
        if {"$x" == "-Xlog:class+dynamic=debug"} {
            continue
        }
        if {![regexp {^[-]} $x]} {
            # only skip duplicate options, not actual program args
            set dontskip 1
        }
        set y $x
        regsub {^[-]XX[+-]} $y "" y
        if {$dontskip || ![info exists seen($y)] || "$y" == "-XX:+UnlockDiagnosticVMOptions"} {
            set seen($y) 1
            set new_list [concat [list $x] $new_list]
        }
    }

    set cmd_list $new_list
}

proc print_for_bash {fd cmd options exports} {
    global bash_prefix nativepath classpath env
    puts $fd "cd /home/iklam/tmp/$env(JTREG_DIR)/work/scratch"
    set bash_prefix ""

    if {[info exists nativepath]} {
        set exports [concat "LD_LIBRARY_PATH=$nativepath" $exports]
    }
    if {[info exists classpath]} {
        set exports [concat "CLASSPATH=$classpath" $exports]
    }

    foreach exp $exports {
        if {![info exists printed($exp)]} {
            set printed($exp) 1
            if {![regexp ^DISPLAY=: $exp]} {
                puts $fd "export $exp"
            }
        }
    }

    set preopts ""
    set postopts ""
    set pre 1
    foreach o $options {
        if {"$o" == "--"} {
            set pre 0
        } elseif {$pre} {
            lappend preopts $o
        } else {
            lappend postopts $o
        }
    }

    set n 0
    set is_not_option 0
    set is_cp 0
    set seen_main 0

    global cmd_list
    set cmd_list {}

    foreach w $cmd {
        if {$n == 1} {
            foreach x $preopts {
                append_cmd $x
            }
        }
        if {!$is_not_option && $n > 0} {
            if {("$w" == "-cp" || "$w" == "-classpath" || "$w" == "--add-exports" || "$w" == "--add-modules")} {
                set is_not_option 1
                set is_cp 1
            } else {
                set is_not_option 0
                set is_cp 0
                if {!$seen_main && ![regexp {^[-]} $w]} {
                    # This is the main class
                    set seen_main 1
                    foreach x $postopts {
                        append_cmd $x
                    }
                }
            }
        } else {
            set is_not_option 0
            if {$is_cp && [info exists classpath] && "$w" == "$classpath"} {
                unset classpath
            }
            set is_cp 0
        }
        append_cmd $w
        incr n
    }
    if {!$seen_main} {
        # We are running a dump.
        foreach w $postopts {
            append_cmd $w
        }
    }

    clean_cmd_list
    foreach x $cmd_list {
        append_for_bash $fd $x
    }

    puts $fd ""
}

proc found_one_cmd {cmd {exports {}}} {
    global env which n vm options
    if {[info exists env(jvm)] && "$env(jvm)" != ""} {
        regsub {^[^ ]+} $cmd $env(jvm) cmd
    }

    regsub -all {[-]Dtest.modules=([^-]+) } $cmd " {-Dtest.modules=\\1} " cmd
    regsub -all {[-]J[-]D} $cmd {-D} cmd
    regsub {[-]cp [^ ]+/4.2/promoted/latest/binaries/jtreg/lib/jtreg.jar } $cmd {-DXXXXXX } cmd

    set first [lindex $options 0]
    if {"$first" == "-gdb" || "$first" == "-gdbauto"} {
        set my_options [concat $first {-XX:+UnlockDiagnosticVMOptions -XX:+LogVMOutput -XX:LogFile=/tmp/ioi.vmlog } [lrange $options 1 end]]
    } else {
        set my_options [concat        {-XX:+UnlockDiagnosticVMOptions -XX:+LogVMOutput -XX:LogFile=/tmp/ioi.vmlog } $options]
    }

    #puts $my_options; exit

    if {"$which" == ""} {
        puts "\[$n\]======================================================================"
        print_for_bash stdout $cmd $my_options $exports
    }

    if {"$which" == "$n"} {
        set fd [open /tmp/reruncds.sh w+]
        if {"$vm" != ""} {
            regsub {^[^ ]+} $cmd "$vm" cmd
        }
        print_for_bash $fd $cmd $my_options $exports
        close $fd
        puts " --- to debug ---"
        puts "bash -c /tmp/reruncds.sh"
        exit
    }
}

set jtrfile {}
set n 0
set date 0
foreach a $argv {
    if {[regexp {[.]jtr$} $a]} {
        incr num_jtrs
        set t [file mtime $a]
        if {$t > $date} {
            if {$jtrfile != ""} {
                #puts "  Skipping older file $jtrfile"
            }
            set date $t
            set jtrfile $a
        } else {
            #puts "  Skipping older file $a"
        }
    } else {
        break
    }
    incr n
}
puts "Found jtr = $jtrfile"


set which [lindex $argv [expr $n]]
set vm [lindex $argv [expr $n + 1]]
set options [lrange $argv [expr $n + 2] end]

set fd [open $jtrfile]
set data [read $fd]
regexp "CLASSPATH=(\[^ \t\n\]+)" $data dummy classpath
close $fd


set fd [open $jtrfile]
set n 0
while {![eof $fd]} {
    set line [gets $fd]
    regexp "\[-\]Djava.library.path=(\[^ \n\]+)" $line dummy nativepath

    if {[regexp "^Command line: .(.*).$" $line dummy cmd]} {
        incr n
        # If there are two -cp, remove the first one (jtreg long stuff crap)
        if {[regexp {[-]cp .*[-]cp } $cmd]} {
            regsub {[-]cp [^ ]+ } $cmd "" cmd
        }

        set pat {=([^ ]+/scratch/[^/]+)}

        foreach jsa [split $line " "] {
            if {![regexp {/.*/scratch/.*} $jsa jsa]} {
                continue
            }
            regsub {^/a:/} $jsa / jsa
            #puts --->$jsa
            set jsadir [file dirname $jsa]
            file mkdir $jsadir
            set jtrdir [file root $jtrfile]
            set saved $jtrdir/[file tail $jsa]

            if {![file exists $jsa] || (0 && [file size $jsa] != [file size $saved])} {
                if {[file exists $saved]} {
                    puts "restoring $jsa from $saved"
                    file delete $jsa
                    exec ln $saved $jsa
                } elseif {![regexp {[-]Xshare:dump} $cmd]} {
                    puts "Cannot find saved jsa file for $jsa"
                    puts "Should be at                   [file normalize $saved]"
                    if {"$which" != ""} {
                        #exit 1
                    }
                }
            }
        }
        found_one_cmd $cmd
    }
}

if {$n == 0 &&
    [regsub -all {[-][-]rerun:} $data \uffff data2] &&
    [regexp {\uffff.*[-][-][-][-][-][-][-][-]([^\uffff]*)} $data2 dummy cmd]} {
    # This doesn't spawn any child VMs. It's probably not a CDS test. Let's list all the (non-compiler) commands executed by jtreg
    set reruns [split $data2 \uffff]
    for {set x 1} {$x < [llength $reruns]} {incr x} {
        set cmd [lindex $reruns $x]

        if {[regexp {/bin/javac \\\\} $cmd]} {
            continue
        }

        regsub -all {\\\\} $cmd \\ cmd
        regsub "^\[^\n\]*\n" $cmd "" cmd
        regsub "\nresult: .*" $cmd "" cmd
        regsub "^\n*cd\[^\n\]*\n" $cmd "" cmd
        regsub -all " *\\\\\n *" $cmd "\ufffe" cmd

        set list {}
        foreach i [split $cmd "\ufffe"] {
            set i [string trim $i]
            if {![regexp ' $i]} {
                foreach i [split $i " "] {
                    lappend list $i
                }
            } else {
                lappend list $i
            }
        }

        set exports {}
        set newcmd {}
        set state 1
        foreach i $list {
            if {$state == 1} {
                if {[regexp {^([A-Za-z0-9_]+)=.*} $i exp]} {
                    lappend exports $exp
                    continue
                }
            }
            set state 2
            lappend newcmd $i
        }

        incr n
        found_one_cmd $newcmd $exports
    }
}

close $fd

if {$which == ""} {
    puts ==============================usage==============================
    puts "reruncds $jtrfile <which> <jvm> <preopts ...> <--> <postopts ...>"
    puts "The first of <preopts> may be -gdb"
}
