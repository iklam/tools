# See ../setup/_gdbinit -- hook-stop
#
# This is a simple GUI interface for displaying the callstackgdb callstack, and quickly linking that to emacs.
#

source [file dirname [info script]]/../lib/xraise.tcl

proc main {} {
    global argv
    if {[lindex $argv 0] == "-breakpoint"} {
        set mywinid "-"
        catch {
            set active [string trim [exec xprop -root _NET_ACTIVE_WINDOW]]
            regexp {0x[0-9a-f]+$} $active mywinid
        }
        catch {
            set fd [socket localhost 9988]
            set f [lindex $argv 1]
            regsub {<[0-9]+>} $f "" f
            puts $fd "breakpoint $f [lindex $argv 2] $mywinid"
            close $fd
        }
        exit
    } else {
        set existing 0
        catch {
            set fd [socket localhost 9988]
            puts $fd focus
            close $fd
            set existing 1
        }

        if {!$existing} {
            make_gui
            socket -server do_connect 9988
           #socket -server do_distcc_connect 9989
        }
    }
}

set tm 0
set tg 0
catch {set tm [file mtime /tmp/lastmake]}
catch {set tg [file mtime /tmp/gdb.status.txt]}
if {$tm > $tg} {
    set view_mode make
} else {
    set view_mode gdb
}

proc make_gui {} {
    global hlist view_mode wrapStyle nowrapStyle hide_vm_errors
    global distcc_order distcc_active distcc_total distcc_selected distcc_btn
    package require Tix
    wm protocol . WM_DELETE_WINDOW exit
    wm geometry . 480x900-0+195

    set wrapStyle [tixDisplayStyle text]
    set nowrapStyle [tixDisplayStyle text]

    set t [frame .t]
    pack $t -fill both -expand yes
    set f [frame .t.toprow]
    set f2 [frame .t.toprow2]
    set hide_vm_errors 1
    checkbutton $f.ck0 -text "Hide Errors" -variable hide_vm_errors -command refresh
    checkbutton $f.ck1 -text "Emacs"   -variable enable_sync_emacs
    checkbutton $f.ck2 -text "GDB"   -variable enable_sync_gdb
    button $f.b1 -text "Emacs" -command {force_sync emacs}
    button $f.b2 -text "GDB" -command {force_sync gdb}
    pack $f.ck0  $f.ck1 $f.ck2 $f.b1 $f.b2 -side left

    button $f2.b3 -text "Copy" -command copy_the_clipboard
    button $f2.b4 -text "Copy (args)" -command {copy_the_clipboard 1}
    checkbutton $f2.ck1 -text "Group errors" -variable group_errors -command refresh
    pack $f2.b3 $f2.b4  $f2.ck1 -side left

    pack $f -side top -fill both -anchor w
    pack $f2 -side top -fill both -anchor w
    set sl [tixScrolledHList $t.sl -options {
	hlist.columns 4
    }]
    pack $sl -expand yes -fill both
    frame $t.botrow0
    frame $t.botrow1
    frame $t.botrow2

    button $t.switch -text "Showing $view_mode" -command switch_view

    pack $t.botrow2 -side bottom -fill x
    pack $t.botrow1 -side bottom -fill x
    pack $t.botrow0 -side bottom -fill x
    pack $t.switch -in $t.botrow2

    set n 0
    foreach host $distcc_order {
        incr n
        if {$n > 2} {
            set frame $t.botrow1
        } else {
            set frame $t.botrow0
        }
        set distcc_selected($host) 1
        set cbtext $host
        regsub ioi $cbtext "" cbtext
        checkbutton $t.dist_$host -text $cbtext -variable distcc_selected($host) -command update_available_hosts
        pack $t.dist_$host -in $frame -side left
        set distcc_active($host) 0
        set distcc_total($host) 0
        set distcc_btn($host) $t.dist_$host 
    }
    set distcc_btn(elapsed) [label $t.botrow1.elapsed -text "Elapsed 00:00"]
    pack $distcc_btn(elapsed) -side left


    set hlist [$sl subwidget hlist]
    $hlist config -selectforeground black -selectbackground #a0a0ff -command sync_emacs -font {{DejaVu Sans Mono} -10} -columns 4
    $hlist config -browsecmd browse_hlist

    foreach style [list $wrapStyle $nowrapStyle] {
        $style config -font {{DejaVu Sans Mono} -10} -anchor n \
            -background [$hlist cget -background] \
            -foreground [$hlist cget -foreground] \
            -selectbackground [$hlist cget -selectbackground] \
            -selectforeground [$hlist cget -selectforeground]
    }

    bind $hlist <ButtonRelease-1> "frame_select $hlist %x %y"
    #bind $hlist <1> "wm focus $t"

    after 300 refresh_live_gdbs
    #after 600 set_the_icon
}

# This file should have something like this. The number is how many
# concurrent jobs should be executed on that host
#
# set distcc_cpus(localhost)   32
# set distcc_cpus(remotehost1) 16
# set distcc_cpus(remotehost2) 16
#
# Dispatch all jobs to localhost first. When localhost is running 32 jobs
# then start dispatching to remotehost1, then to remotehost2
#
# set distcc_order {localhost remotehost1 remotehost2}

source ~/.distcc.config.tcl

proc refresh_live_gdbs {} {
    global gdb_live last_gdbpid gdb_active
    set f .t.gdbs

    if {![winfo exist $f]} {
        frame $f
        pack $f -side bottom -fill both -anchor w
    }

    catch {unset gdb_live}
    catch {unset gdb_active}

    foreach file [glob -nocomplain /tmp/gdb-live-*.txt] {
        if {[regexp {[-]([0-9]+)[.]txt} $file dummy pid]} {
            set is_alive  0
            set is_active 0
            set cmd {}
            catch {
                set data [exec ps -o stat,cmd $pid]
                if {[regexp {[A-z]+[+] +gdb(.*)} $data dummy cmd]} {
                    set is_alive 1
                    set is_active 1
                    set gdb_active($pid) 1
                } elseif {[regexp {[A-z]+ +gdb(.*)} $data dummy cmd]} {
                    set is_alive 1
                }
            }

            regsub {.*[-][-]args [^ ]*/java } $cmd "java " cmd
            set row $f.$pid

            if {!$is_alive} {
                puts "Removing non-alive $file"
                catch {
                    file delete -force $file
                }
            } else {
                if {![winfo exists $row]} {
                    #puts "Creating $row"
                    frame $row
                    set b [button $row.focus -text F -width 6 -anchor w -command "activate_gdb $pid"]
                    set c [radiobutton $row.check -text " $cmd" -anchor w -variable last_gdbpid -value $pid -command gdb_radiobutton_selected]
                    pack $b -side left -fill both
                    pack $c -side left -fill both
                    pack $row -fill both
                }
                catch {uplevel #0 source $file}
                $row.focus config -text [get_window_name $gdb_live($pid,win)]

                if {$is_active} {
                    $row.focus config -fg black
                    $row.check config -fg black
                } else {
                    $row.focus config -fg darkgrey
                    $row.check config -fg darkgrey
                }
            }
        }
    }

    foreach row [winfo children $f] {
        regsub {.*[.]} $row "" pid
        if {![info exists gdb_live($pid,win)]} {
            #puts "forgetting $row"
            pack forget $row
            destroy $row

            if {[info exists last_gdbpid] && $last_gdbpid == $pid} {
                set last_gdbpid ""
            }
        } else {
            if {![info exists livepid]} {
                set livepid $pid
            }
        }
    }

    if {![info exists last_gdbpid] || $last_gdbpid == ""} {
        if {[info exists gdb_live] && [info exists livepid]} {
            set last_gdbpid $livepid
            #refresh_gdb
        }
    }

    foreach file [glob -nocomplain /tmp/gdb-status-*.txt] {
        if {[regexp {[-]([0-9]+)[.]txt} $file dummy pid]} {
            if {![info exists gdb_live($pid,win)]} {
                puts "deleting $file"
                catch {
                    file delete -force $file
                }
            }
        }
    }

    #if {[info exists gdb_live]} {parray gdb_live}

    after 300 refresh_live_gdbs
}

proc get_window_name {xwinid} {
    set name ??
    catch {
        set data [exec xwininfo -id $xwinid]
        regexp "xwininfo: Window id: 0x\[0-9a-f\]+ \"(\[^\"\]+)\"" $data dummy name
    }
    return $name
}

proc activate_gdb {pid} {
    global gdb_live
    exec wmctrl -i -a $gdb_live($pid,win)
}

proc browse_hlist {index} {
    global hlist wrapStyle nowrapStyle view_mode

    if {$view_mode == "make"} {
        foreach i [$hlist info children] {
            $hlist.$i config -wraplength 0 -background [$hlist cget -bg]
        }
        $hlist.$index config -wraplength [expr [winfo width $hlist] - 30] \
            -background [$hlist cget -selectbackground]
    }
}

proc do_select_make {child} {
    global hlist

    $hlist selection clear
    $hlist selection set $child
    browse_hlist $child
    sync_emacs $child
}

proc send_breakpoint {file line winid} {
    global dont_send_key

    regsub {<[^>]*>} $file "" file
    catch {
        unset dont_send_key
    }
    send_keys_to_gdb "b $file:$line"
}

proc gdb_radiobutton_selected {} {
    global dont_send_key view_mode

    set target_mode gdb
    set dont_send_key 1
    refresh

    if {$view_mode != "gdb"} {
        set dont_send_key 1
        switch_view
    }
}

proc do_connect {fd addr port} {
    global gdb_xwindow dont_send_key view_mode last_gdbpid
    set line [gets $fd]
    close $fd
     #puts $line
    if {[regexp {^breakpoint} $line]} {
        send_breakpoint [lindex $line 1] [lindex $line 2] [lindex $line 3]
        return
    }

    set target_mode make
    if {[regexp {refresh gdb (.*)} $line dummy last_gdbpid]} {
        set target_mode gdb
    }
    set dont_send_key 1
    refresh

    if {"$line" == "focus"} {
        set dont_send_key 1
        focus_me .
    }

    if {$view_mode != $target_mode} {
        set dont_send_key 1
        switch_view
    }
}

proc update_available_hosts {} {
    global distcc_selected distcc_order distcc_cpus
    set avail 0
    set fd [open ~/.distcc.selected w+]
    foreach host $distcc_order {
        if {$distcc_selected($host)} {
            incr avail $distcc_cpus($host)
            set s 1
        } else {
            set s 0
        }
        puts $fd "set distcc_selected($host) $s"
    }
    close $fd
    set fd [open ~/.distcc.avail w+]
    puts $fd $avail
    close $fd
}

proc update_hosts_stats {} {
    global distcc_order distcc_active distcc_total distcc_history distcc_btn
    global distcc_start_time

    if {![info exists distcc_history]} {
        return
    }

    foreach host $distcc_order {
        set perc ""
        catch {
            set n [array size distcc_history]
            if {$n > 0} {
                set perc ", [expr int(100.0 * $distcc_total($host) / $n)]%"
            }
            if {$perc == ", 0%"} {
                set perc ""
            }
        }
        set cbtext "$host ($distcc_active($host), $distcc_total($host)$perc)"
        regsub ioi $cbtext "" cbtext
        $distcc_btn($host) config -text $cbtext
    }

    if {[info exists distcc_start_time]} {
        set e [expr [clock seconds] - $distcc_start_time]
        set s [expr $e % 60]
        set m [expr $e / 60]
        $distcc_btn(elapsed) config -text [format "Elapsed %02d:%02d" $m $s]
    }
}

proc set_the_icon {{update 1}} {
    global view_mode icon
    if {$view_mode == "gdb"} {
        set icon icons8-bug-64.png
    } else {
        set icon icons8-construction-48.png
    }
    wm title . $view_mode
    if {[wm frame .] != 0x0} {
        set_wm_icon
    } else {
        after 100 set_wm_icon
    }
}

proc set_wm_icon {} {
    global icon
    if {[wm frame .] != 0x0} {
        set_icon . $icon
    } else {
        after 100 set_wm_icon
    }
}

proc switch_view {} {
    global view_mode lastmake_timestamp
    if {$view_mode == "gdb"} {
        set lastmake_timestamp 0
        set view_mode make
    } else {
        set view_mode gdb
    }
    .t.switch config -text "Showing $view_mode"
    set_the_icon
    refresh first
}

set lastmake_timestamp 0
proc watch_lastmake {} {
    global lastmake_timestamp view_mode

    set f /tmp/lastmake

    if {[file exists $f]} {
        set t [file mtime $f]
        if {$lastmake_timestamp < $t} {
            set lastmake_timestamp $t
            if {$view_mode != "make"} {
                switch_view
            }
            after 1 refresh_make
        }
    }
    after 300 watch_lastmake
}

proc schedule_refresh {ms} {
    global refresh_scheduled
    if {![info exists refresh_scheduled]} {
        after $ms refresh
        set refresh_scheduled 1
    }
}

proc refresh {{mode {}}} {
    global view_mode refresh_scheduled

    catch {unset refresh_scheduled}
    refresh_${view_mode} $mode
}

set stack2file {}
proc refresh_make {{mode {}}} {
    global hlist stack2file wrapStyle nowrapStyle group_errors
    if {![info exists hlist]} {
        return
    }

    $hlist delete all

    for {set i 0} {$i < 10 && ![info exists fd]} {incr i} {
        if {[catch {set fd [open /tmp/lastmake]}]} {
            after 100;
        }
    }
    if {![info exists fd]} {
        return
    }

    foreach w [winfo children $hlist] {
        destroy $w
    }

    set stack2file {}
    set frameid 0
    set n 0
    while {![eof $fd]} {
        set line [gets $fd]
        
        if {[regexp {([^/]+[.].pp:[0-9]+:[0-9]+: error:.*)} $line tail] ||
            [regexp {([^/]+[.].pp:[0-9]+:[0-9]+:.*required from here*)} $line tail] ||
            [regexp {([^/]+[.].pp:[0-9]+:[0-9]+: note: in expansion of macro 'assert'.*)} $line tail]} {

            incr n
            if {$n > 999991} {
                puts DONE
                break
            }

            if {$group_errors} {
                if {[regexp {(.*pp):} $line dummy file] && ![info exists seen($file)]} {
                    set num $frameid
                    $hlist add $frameid -itemtype text -text $num -style $nowrapStyle
                    $hlist item create $frameid 1 -itemtype text -text $file
                    set seen($file) 1
                    incr frameid
                    lappend stack2file $file
                }
                continue
            }

            if {![info exists seen($tail)]} {
                set seen($tail) 1
                set num $frameid
                if {[regsub " error: " $tail "\n    " tail]} {
                    set num $frameid\n
                }
                regsub {(pp:[0-9]+):[0-9]+} $tail \\1 tail
                $hlist add $frameid -itemtype text -text $num -style $nowrapStyle
                if 0 {
                    $hlist item create $frameid 1 -itemtype text -text $tail
                } else {
                    set w [label $hlist.$frameid -text $tail -wraplength 0 -anchor w -justify left \
                               -font {{DejaVu Sans Mono} -10} -bg [$hlist cget -bg]]
                    $hlist item create $frameid 1 -itemtype window -window $w
                    bind $w <ButtonRelease-1> "do_select_make $frameid"
                }
                incr frameid
                set line "$line "
                lappend stack2file $line
            }
        }
    }
    close $fd
    if {$frameid == 0} {
        refresh_compile
    }
}

proc refresh_gdb {{mode {}}} {
    global hlist stack2file dont_send_key last_gdbpid hide_vm_errors report_vm_error_idx

    if {![info exists last_gdbpid] || $last_gdbpid == ""} {
        return;
    }

    $hlist delete all

    for {set i 0} {$i < 10 && ![info exists fd]} {incr i} {
        if {[catch {set fd [open /tmp/gdb-status-${last_gdbpid}.txt]}]} {
            after 100;
        }
    }
    if {![info exists fd]} {
        return
    }
    set read_stack 0
    set stack2file {}
    set frameid 0
    set report_vm_error_idx -1

    while {![eof $fd]} {
        if {[info exists nextline]} {
            set line $nextline
            unset nextline
        } else {
            set line [string trim [gets $fd]]
        }

        if {"$line" == ":where"} {
            set read_stack 1
        } elseif {"$line" == ":where-end"} {
            break
        } elseif {$read_stack} {
            while {![eof $fd]} {
                set nextline [gets $fd]
                if {[regexp {^    (.*)} $nextline dummy rest]} {
                    append line " $rest"
                    unset nextline
                } else {
                    break
                }
            }
            if {[regexp {^#[0-9]+ +((0x[0-9a-f]+ in )|)(.*[\)]) at (.*)} $line dum dum dum frame file] ||
                [regexp {^#[0-9]+ +((<signal handler called>))} $line dum frame file]} {
                if {[regexp "^report_vm_error " $frame]} {
                    set report_vm_error_idx $frameid
                }
                $hlist add $frameid -itemtype text -text $frameid
                $hlist item create $frameid 1 -itemtype text -text $frame
                incr frameid
                lappend stack2file $file
            }
        }
    }
    close $fd

    if {$mode != "first"} {
        #sync_emacs 0
    }

    if {$hide_vm_errors} {
        for {set i 0} {$i <= $report_vm_error_idx} {incr i} {
            $hlist hide entry $i
        }
    }
}

set distcc_finished 0
set lasttime 0
proc refresh_compile {{mode {}}} {
    global hlist distcc_order distcc_active distcc_total distcc_selected distcc_history distcc_finished lasttime
    global distcc_start_time
    set now [clock seconds]
    $hlist delete all

    set fd [open "|ps -ef"]
    set list {}
    while {![eof $fd]} {
        set line [gets $fd]
        if {[regexp {([^ ]+[.]o) } $line dummy obj]} {
            if {[regexp {([^ ]+[.]cpp) } $line dummy cpp]} {
                set found($obj) $cpp
                set lasttime $now
            }
            if {[regexp {ssh ([^ ]+)} $line dummy host]} {
                set remote($obj) $host
            }
        } elseif {[regexp ld.gold $line]} {
            lappend list ".... linking"
        }
    }
    close $fd

    if {[info exists found]} {
        foreach n [array names found] {
            set file [file tail $found($n)]
            catch {
                set h($file) $remote($n)
            }
            lappend list $file
        }
    }

    foreach host $distcc_order {
        set distcc_active($host) 0
    }

    if {$now - $lasttime > 5} {
        set distcc_finished 0
        catch {unset distcc_history}
        catch {unset distcc_start_time}
        foreach host [array names distcc_total] {
            set distcc_total($host) 0
        }
    }

    set n 1
    set m 1
    set left 1
    set objs 0
    foreach file [lsort -dict $list] {
        if {"$file" != "... linking"} {
            incr objs
        }

        set host ""
        if {[info exists h($file)]} {
            set host $h($file)
        }

        if {[info exists distcc_selected($host)]} {
            set who $host
        } else {
            set who localhost
        }

        incr distcc_active($who)
        if {![info exists distcc_history($who,$file)]} {
            if {![info exists distcc_start_time]} {
                set distcc_start_time [clock seconds]
                #xraise gdbwatch.tcl
            }
            set distcc_history($who,$file) 1
            incr distcc_total($who) 1
        }

        set target [format %-10s%s $host $file]
        if {$left == 1} {
            $hlist add $n -itemtype text -text $m
            $hlist item create $n 1 -itemtype text -text $target
            set left 0
        } else {
            $hlist item create $n 2 -itemtype text -text $m
            $hlist item create $n 3 -itemtype text -text $target
            set left 1
            incr n
        }
        incr m
    }
    puts $objs
    if {$n > 1} {
        schedule_refresh 2000
    } else {
        schedule_refresh 5000
    }
    if {$objs == 0} {
        set distcc_finished 1
    }

    update_hosts_stats
}

proc frame_select {hlist x y} {
    sync_emacs [$hlist info selection]
}

set dont_send_key 1
proc send_keys_to_gdb {string} {
    global dont_send_key last_gdbpid gdb_live gdb_active

    #if {[info exists dont_send_key]} {
        #unset dont_send_key
        #return
    #}

    if {![info exists last_gdbpid] || $last_gdbpid == ""} {
        return;
    }

    if {![info exists gdb_active($last_gdbpid)]} {
        return;
    }

    if {[catch {
        set gdb_xwindow $gdb_live($last_gdbpid,win)
        puts $gdb_xwindow
        exec wmctrl -i -a $gdb_xwindow
        after 200
        set fd [open "|xte" w+]
        foreach c [split "$string\n" ""] {
            set shift 0
            if {[regexp {[A-Z]} $c]} {
                set shift 1
            } elseif {"$c" == " "} {
                set c space
            } elseif {"$c" == ":"} {
                set c colon
                set shift 1
            } elseif {"$c" == "."} {
                set c period
            } elseif {"$c" == "_"} {
                set c underscore
                set shift 1
            } elseif {"$c" == "\n"} {
                set c Return
            } elseif {"$c" == "/"} {
                set c slash
            }

            if {$shift} {
                puts $fd "keydown Shift_L"
                puts $fd "keydown $c"
                puts $fd "keyup $c"
                puts $fd "keyup Shift_L"
            } else {
                puts $fd "key $c"
            }
        }
        close $fd
    } err]} {
        puts $err
    }
}

proc sync_emacs {i {force ""}} {
    global stack2file env view_mode enable_sync_emacs enable_sync_gdb
    set file [lindex $stack2file $i]
    if {$view_mode == "gdb"} {
        set env(REVERT) 1
        if {[regexp {^(/.*):([0-9]+)} $file dummy file line]} {
            if {($force == "" && $enable_sync_emacs) || $force == "emacs"} {
                edit_in_emacs $file +$line
                set has_synced_emacs 1
            }
        }
        if {![info exists has_synced_emacs] && ($enable_sync_gdb || $force == "gdb")} {
            send_keys_to_gdb "frame $i"
        }
    } else {
        set env(REVERT) 0
        if {[regexp {^(/.*):([0-9]+):([0-9]+)} $file dummy file line char]} {
            edit_in_emacs $file +$line
        }
    }
}

proc force_sync {which} {
    global hlist report_vm_error_idx

    if {[info exists report_vm_error_idx]} {
        if {[$hlist info selection] == ""} {
            set i [expr $report_vm_error_idx + 1]
            $hlist selection clear
            $hlist selection set $i
        }

        browse_hlist [$hlist info selection]
        sync_emacs [$hlist info selection] $which
    }
}

proc copy_the_clipboard {{copy_args 0}} {
    global view_mode hlist
    if {$view_mode == "gdb"} {
        set frames [$hlist info children]
        if {[llength $frames] >= 100} {
            set fmt %3d
        } elseif {[llength $frames] >= 10} {
            set fmt %2d
        } else {
            set fmt %d
        }

        set text ""
        foreach frameid [lsort -increasing -integer $frames] {
            set frame [$hlist item cget $frameid 1 -text]
            if {$copy_args == 0} {
                regsub {[(].*[)]} $frame "" frame
            }
            # remove the template args -- they are almost always useless clutters
            regsub -all { *<[^>]*>} $frame "" frame
            regsub -all {=[.][.][.]} $frame "" frame
            regsub -all {__the_thread__} $frame THREAD frame
            append text "[format $fmt $frameid] $frame"
            append text \n
        }

        catch {
            set fd [open "|xclip" w+]
            puts -nonewline $fd $text
            close $fd
        }
    }
}

main
refresh first
watch_lastmake
update_available_hosts
