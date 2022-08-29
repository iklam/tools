# Display a list of the current buffers in emacs
# emacsclient -e '(buffer-list)'
source [file dirname [info script]]/../lib/xraise.tcl

package require Tix

proc refresh {} {
    global paths buffers

    catch {unset paths}
    exec emacsclient -e (ioi-list-buffers)
    set fd [open /tmp/emacs-buffers]
    set buffers {}
    while {![eof $fd]} {
        set buffer [gets $fd]
        set path [gets $fd]

        if {[string trim $buffer] != ""} {
            lappend buffers $buffer
            regsub {^/home/iklam/jdk/} $path /jdk/ path
            regsub {^/home/iklam/tmp/} $path /jdk/tmp/ path
            set paths($buffer) $path
        }
    }
    close $fd
    update_hlist
}

proc mycompare {a b} {
    set roota [file root $a]
    set rootb [file root $b]

    regsub ^_ $roota . roota
    regsub ^_ $rootb . rootb

    if {"$roota" == "$rootb"} {
        set exta [file ext $a]
        set extb [file ext $b]

        if {"$exta" == ".hpp" || "$extb" == ".cpp"} {
            return -1
        }
        if {"$extb" == ".hpp" || "$exta" == ".cpp"} {
            return 1
        }
    }
    return [string compare -nocase $roota $rootb]
}

proc sort_by_checked {buffers} {
    global checked
    set list {}
    for {set i 0} {$i <= 1} {incr i} {
        foreach buffer $buffers {
            set orig_tail $buffer
            regsub {<.*} $orig_tail "" orig_tail

            if {[info exists checked($orig_tail)] ^ $i} {
                lappend list $buffer
            }
        }
    }
    return $list
}

proc update_hlist {} {
    global hlist buffers paths sorted next_hilite lastfile winstyle onstyle offstyle checked
    $hlist delete all

    if {$sorted} {
        set sorted_buffers [lsort -command mycompare $buffers]
    } else {
        set sorted_buffers [sort_by_checked $buffers]
    }

    if {![info exists winstyle]} {
        set bg  [$hlist cget -bg]
        set sbg [$hlist cget -selectbackground]
        set fg [$hlist cget -fg]

        set winstyle [eval tixDisplayStyle window    -padx 0 -pady 0 -bg $bg]
        set onstyle  [eval tixDisplayStyle text      -bg $bg -padx 0 -pady 0]
        set offstyle [eval tixDisplayStyle text      -bg $bg -padx 0 -pady 0 -fg $bg -selectforeground $sbg]
    }
    set n 0
    foreach buffer $sorted_buffers {
        set path $paths($buffer)
        set name $buffer
        set repo ""
        if {[regexp {/jdk2*/bld/([a-z]+)} $path dummy repo] ||
            [regexp {/jdk2*/([a-z]+)/} $path dummy repo] ||
            [regexp {/jdk3*/bld/([a-z]+)} $path dummy repo] ||
            [regexp {/jdk3*/([a-z]+)/} $path dummy repo]} {
            regsub {<[^>]+>} $name "" name
        }

        set orig_tail $name
        regsub {<.*} $orig_tail "" orig_tail
        if {[info exist checked($orig_tail)]} {
            set style $onstyle
        } else {
            set style $offstyle
        }
        $hlist add $buffer -itemtype text -text " X " -style $style
        $hlist item create $buffer 1 -itemtype text -text $name
        $hlist item create $buffer 2 -itemtype text -text $repo
    }
    if {[info exists next_hilite]} {
        $hlist selection set $next_hilite
        set lastfile $next_hilite
        unset next_hilite
    }
    do_select
}

set lastfile ""
set lasttime 0
proc doit_hlist {file} {
    global hlist lastfile lasttime
    set now [clock seconds]

    if {$now - $lasttime > 1 || "$file" != "$lastfile"} {
        set lastfile $file
        set lasttime $now
        exec emacsclient -e "(switch-to-buffer \"$file\")"
        xraise emacs23 1
    }
    focus .e
}

set selection ""
set sorted 0
set repo ""
set repo_only 1
proc make_ui {} {
    global hlist  kill_enabled always_up
    set kill_enabled 0
    set always_up 1
    #wm geometry . 328x336+0+0
    wm geometry . 328x336+365+263
    frame .f
    entry .w -textvariable repo -width 4 -exportselection false
    entry .e -textvariable selection -exportselection false
    button .clear -text \u2a2f -padx 3 -command {set selection ""; focus .e}
    checkbutton .ck -variable sorted -text \u2193
    checkbutton .ro -variable repo_only
    tixScrolledHList .b -options {
        hlist.columns 3
    }

    set hlist [.b subwidget hlist]
    $hlist config -separator \uFFFF -font {{DejaVu Sans Mono} -10} -selectforeground black -selectbackground #a0a0ff -browsecmd doit_hlist \
        -bg #d0d0a0

    frame .buttons
    button .r -text Refresh -command refresh
    label .always_up -text \u2195 -padx 4 -relief sunken -border 1 -bg #b0b0b0
    button .k -text *K* -command kill -fg #602020 -state disabled
    button .k30 -text *K30* -command kill30 -fg #602020 -state disabled
    checkbutton .ke -command toggle_kill -variable kill_enabled
    pack .always_up -in .buttons -side right -padx 4
    pack .r -in .buttons -side right -padx 40 -pady 4
    pack .k -in .buttons -side left -pady 4
    pack .k30 -in .buttons -side left -pady 4
    pack .ke -in .buttons -side left -pady 4
    pack .buttons -side bottom -fill x
    pack .f -side top -fill x
    pack .w -in .f -side left -expand yes -fill both -padx 2 -pady 2
    pack .ro -in .f -side left
    pack .e -in .f -side left -expand yes -fill both -padx 2 -pady 2
    pack .clear -in .f -side left
    pack .ck -in .f -side left
    pack .b -expand yes -fill both
    dofocus .e

    update idletasks
    set_icon . icons8-restaurant-menu-48.png
    bind .w <1> {dofocus .w}
    bind .k <1> {dofocus .k}
    bind .w <Control-w> {dofocus .e}
    bind .  <Control-w> {dofocus .e}
    bind .  <Control-q> {dofocus .w}
    bind .e <Control-q> {dofocus .w}
    bind .e <Control-x> {set selection ""}
    bind all <Tab> {
        if {$the_focus == ".w" || [focus -displayof .] == ".w"} {
            dofocus .e
        } else {
            dofocus .w
        }
        break
    }
    bind .always_up <ButtonRelease-1> {toggle_always_up %x %y}

    bind . <Visibility>    set_visibility_changed
    bind . <FocusIn>       {clear_hidden; dofocus .w}

    bind $hlist <1>               {if {[hlist_down %x %y]} break}
    bind $hlist <ButtonRelease-1> {if {[hlist_up   %x %y]} break}
    bind .w <FocusIn> {.w select range 0 end; break}
    bind .e <FocusIn> {.e select range 0 end; break}
}

proc hlist_down {x y} {
    global checking_item hlist checked onstyle offstyle
    catch {unset checking_item}

    if {$x < [$hlist column width 0]} {
        set child [$hlist nearest $y]
        if {$child != ""} {
            set checking_item $child
            set orig_tail $child
            regsub {<.*} $orig_tail "" orig_tail
            if {[info exists checked($orig_tail)]} {
                $hlist item config $child 0 -style $offstyle
            } else {
                $hlist item config $child 0 -style $onstyle
            }
            return 1
        }
    }
    return 0
}
proc hlist_up {x y} {
    global checking_item hlist checked onstyle offstyle

    if {[info exists checking_item]} {
        set child [$hlist nearest $y]
        if {$child == $checking_item} {
            set orig_tail $child
            regsub {<.*} $orig_tail "" orig_tail
            puts "toggle $child - $orig_tail"
            if {[info exist checked($orig_tail)]} {
                unset checked($orig_tail)
            } else {
                set checked($orig_tail) 1
            }
            update_hlist
        } else {
            set child $checking_item
            puts "cancel $child"
            if {[info exists checked($child)]} {
                $hlist item config $child 0 -style $onstyle
            } else {
                $hlist item config $child 0 -style $offstyle
            }
        }
        unset checking_item
        return 1
    }
    return 0
}

set the_focus ""

proc dofocus {w} {
    global the_focus

    if {[wm overrideredirect .]} {
        wm withdraw .
        wm overrideredirect . 0
        wm deiconify .
    }

    set the_focus $w
    puts "Setting $the_focus"
    focus $w
}

proc find_next_hilite {current} {
    global hlist next_hilite

    catch {unset next_hilite}
    for {set n [$hlist info next $current]} {"$n" != ""} {set n [$hlist info next $n]} {
        if {![$hlist info hidden $n]} {
            set next_hilite $n
            puts "NEXT = $n"
            break
        }
    }
}

proc toggle_kill {} {
    global kill_enabled
    if {$kill_enabled} {
        .k config -state active
        .k30 config -state active
    } else {
        .k config -state disabled
        .k30 config -state disabled
    }
}

proc kill30 {} {
    global killcount
    if {![info exists killcount]} {
        set killcount 30
    }
    if {$killcount > 0} {
        incr killcount -1
        kill
        after idle kill30
    } else {
        unset killcount
    }
}


proc kill {} {
    global hlist lastfile
    if {"$lastfile" != "" && ![$hlist info hidden $lastfile]} {
        set next [find_next_hilite $lastfile]

        set file $lastfile
        set lastfile ""
        set lasttime 0
        exec emacsclient -e "(kill-buffer \"$file\")"
        after idle refresh
    }
}

proc sorted_updated {args} {
    global selection afterid env repo
    update_hlist

    set fd [open $env(HOME)/.ioiconfig/emacs_current_repo w+]
    puts $fd $repo
    close $fd
}

proc selection_updated {args} {
    global selection afterid
    if {![info exists afterid]} {
        set afterid [after idle do_select]
    }
}

proc do_select {} {
    global selection afterid hlist paths repo repo_only
    set start [clock milliseconds]
    # Don't want to use $selection as a list since it may contain illegal
    # chars such as parenthesis
    set list {}
    set is_and 0
    foreach part [split $selection " "] {
        set part [string tolower [string trim $part]]
        if {$part != ""} {
            if {$part == "&"} {
                set is_and 1
            } else {
                lappend list $part
            }
        }
    }

    #puts $list
    foreach child [$hlist info children] {
        if {[llength $list] == 0 && "$repo" == ""} {
            $hlist show entry $child
        } else {
            if {[llength $list] == 0} {
                set matched 1
            } else {
                set matched 0
            }
            set lower [string tolower $child]
            foreach pat $list {
                if {[string first "/" $pat] == 0} {
                    #puts $paths($child)
                    if {[string first /jdk$pat $paths($child)] >= 0} {
                        incr matched
                    }
                } else {
                    #puts $pat
                    if {[string first $pat $lower] >= 0} {
                        #puts a
                        incr matched
                    } elseif {[string match $pat $lower]} {
                        #puts b
                        incr matched
                    } else {
                        set m 0
                        catch {
                            set m [regexp $pat $lower]
                        }
                        if {$m} {
                            #puts c
                            incr matched
                        }
                    }
                }
                if {!$is_and && $matched} {
                    break;
                }
            }

            if {$is_and && $matched != [llength $list]} {
                set matched 0
            }

            if {$repo != ""} {
                set r [$hlist item cget $child 2 -text]
                if {"$r" == ""} {
                    if {$repo_only == 1} {
                        set matched 0
                    }
                } else {
                    if {[string first $repo $r] != 0} {
                        set matched 0
                    }
                }
            }
            if {$matched} {
                #puts "show = $child"
                $hlist show entry $child
            } else {
                #puts "hide = $child"
                $hlist hide entry $child
            }
        }
    }

    catch {
        unset afterid
    }
    puts "Elapsed = [expr [clock millisec] - $start] $start"
}

proc main {} {
    global argv selection sorted repo repo_only
    set port 9990
    if {[catch {
        set fd [socket localhost $port]
        puts $fd refresh
        close $fd
        exit
    } err]} {
        #puts "Cannot open socket $port"
        #puts $err
    }

    #wm geometry . 240x400-250+0
    #wm geometry . 240x608+192+428
    #wm overrideredirect . 1
    wm title . "bufie"
    make_ui
    refresh
    trace add variable selection write selection_updated
    trace add variable sorted write sorted_updated
    trace add variable repo write sorted_updated
    trace add variable repo_only write sorted_updated

    bind . <Escape> "wm iconify ."

    socket -server do_connect $port
}

proc do_connect {fd addr port} {
    global is_hidden always_up
    set line [gets $fd]
    close $fd
    puts "command: $line - $always_up"
    if {[string comp $line "raiseifhidden"] == 0} {
        if {$is_hidden && $always_up == 1} {
            if 0 {
                focus_me .
            } else {
                if {[wm overrideredirect .]} {

                } else {
                    wm withdraw .
                    wm overrideredirect . 1
                    wm deiconify .
                }
            }
            xraise emacs23 1
            set is_hidden 0
        }
        return
    }

    if {[wm state .] == "normal" && !$is_hidden} {
        if {[wm overrideredirect .]} {

        } else {
            wm iconify .
        }
    } else {
        if {[wm overrideredirect .]} {
            wm withdraw .
            wm overrideredirect . 0
            wm deiconify .
        }
        focus_me .
    }

    clear_hidden
}

proc clear_hidden {} {
    global is_hidden got_focus_time
    set got_focus_time [clock milliseconds]
    set is_hidden 0
}

proc toggle_always_up {x y} {
    global always_up
    set w .always_up
    if {$x >= 0 && $y >= 0 && $x < [winfo width $w] && $y < [winfo height $w]} {
        if {$always_up == 0} {
            $w config -relief sunken -bg #b0b0b0
            set always_up 1
        } else {
            $w config -relief raised -bg [. cget -bg]
            set always_up 0

            if {[wm overrideredirect .]} {
                wm withdraw .
                wm overrideredirect . 0
                wm deiconify .
            }
        }
    }
}

set is_hidden 0
set got_focus_time [clock milliseconds]

proc set_visibility_changed {} {
    global is_hidden got_focus_time

    if {!$is_hidden && [clock milliseconds] - $got_focus_time > 400} {
        puts "is_hidden [clock milliseconds]"
        set is_hidden 1
    }
}

main
