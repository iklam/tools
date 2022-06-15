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
    package require Tix
    wm protocol . WM_DELETE_WINDOW exit
    wm geometry . 480x900-0+165

    set wrapStyle [tixDisplayStyle text]
    set nowrapStyle [tixDisplayStyle text]

    set t [frame .t]
    pack $t -fill both -expand yes
    set f [frame .t.toprow]
    set hide_vm_errors 1
    checkbutton $f.ck0 -text "Hide Errors" -variable hide_vm_errors -command refresh
    checkbutton $f.ck1 -text "Emacs"   -variable enable_sync_emacs
    checkbutton $f.ck2 -text "GDB"   -variable enable_sync_gdb
    button $f.b1 -text "Emacs" -command {force_sync emacs}
    button $f.b2 -text "GDB" -command {force_sync gdb}
    button $f.b3 -text "Copy" -command copy_the_clipboard
    button $f.b4 -text "Copy (args)" -command {copy_the_clipboard 1}
    pack $f.ck0  $f.ck1 $f.ck2 $f.b1 $f.b2 $f.b3 $f.b4 -side left
    pack $f -side top -fill both -anchor w
    set sl [tixScrolledHList $t.sl -options {
	hlist.columns 2
    }]
    pack $sl -expand yes -fill both
    button $t.switch -text "Showing $view_mode" -command switch_view

    pack $t.switch -side bottom

    set hlist [$sl subwidget hlist]
    $hlist config -selectforeground black -selectbackground #a0a0ff -command sync_emacs -font {{DejaVu Sans Mono} -10} -columns 2
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

    after 300 regresh_live_gdbs
    #after 600 set_the_icon
}

proc regresh_live_gdbs {} {
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

    after 300 regresh_live_gdbs
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

proc refresh_make {{mode {}}} {
    global hlist stack2file wrapStyle nowrapStyle
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
    while {![eof $fd]} {
        set line [gets $fd]
        if {[regexp {([^/]+[.].pp:[0-9]+:[0-9]+: error:.*)} $line tail] ||
            [regexp {([^/]+[.].pp:[0-9]+:[0-9]+:.*required from here*)} $line tail] ||
            [regexp {([^/]+[.].pp:[0-9]+:[0-9]+: note: in expansion of macro 'assert'.*)} $line tail]} {
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

proc refresh_compile {{mode {}}} {
    global hlist

    $hlist delete all

    set fd [open "|ps -ef"]
    set list {}
    while {![eof $fd]} {
        set line [gets $fd]
        if {[regexp {([^ ]+[.]o) } $line dummy obj]} {
            if {[regexp {([^ ]+[.]cpp) } $line dummy cpp]} {
                set found($obj) $cpp
            }
        } elseif {[regexp ld.gold $line]} {
            lappend list ".... linking"
        }
    }
    close $fd

    if {[info exists found]} {
        foreach n [array names found] {
            lappend list [file tail $found($n)]
        }
    }

    set n 1
    foreach file [lsort -dict $list] {
        set host ""
        if {[info exists h($file)]} {
            set host $h($file)
        }
        $hlist add $n -itemtype text -text $n
        $hlist item create $n 1 -itemtype text -text [format %-10s%s $host $file]
        incr n
    }

    if {$n > 0} {
        schedule_refresh 2000
    } else {
        schedule_refresh 5000
    }
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
