# I need to use this because gnome-panel no longer works with the new ubuntu Gnome desktop.

set cur_desktop -1
set always_show_done 0

proc update {args} {
    #puts update
    global cur_desktop always_show_done last_used last_activated
    if {"$args" != "-force"} {
        after 300 update
    }
    set data [exec xprop -root]
    set c $cur_desktop
    regexp {_NET_CURRENT_DESKTOP.CARDINAL. = ([0-9]+)} $data dummy c
    if {$c == $cur_desktop && $always_show_done && "$args" != "-force"} {
        return
    }

    set cur_desktop $c
    foreach w [winfo children .] {
        if {![regexp desktop $w] && "$w" != ".bottom"} {
            destroy $w
        }
    }
    foreach w [winfo children .bottom] {
        destroy $w
    }
    set list {}
    set fd [open "|xwininfo -root -tree"]
    while {![eof $fd]} {
        set line [gets $fd]
        if {[regexp {(Gnome-terminal)|("emacs@ioilinux2")|(the_emacs)} $line]} {
            #puts $line
            if {[regexp {(0x[0-9a-f]+).*[+]([0-9]+)[+]} $line dummy id xpos]} {
                set xpos [format %08x $xpos]
                set data [exec xprop -id $id]
                if {[regexp {_NET_WM_DESKTOP.CARDINAL. = ([0-9]+)} $data dummy desktop] &&
                    [regexp {_NET_WM_ICON_NAME.UTF8_STRING. = \"([^\"]+)\"} $data dummy name]} {
                    if {"$name" == "the_emacs"} {
                        set name EM1
                    } elseif {"$name" == "emacs@ioilinux2"} {
                        set name EM2
                    }

                    if {$desktop == $cur_desktop || $desktop == 4294967295} {
                        lappend list $name==$xpos==$id
                    }
                }
            }
        } elseif {!$always_show_done && [regexp {(0x[0-9a-f]+).*window_switcher.tcl} $line dummy id]} {
            #puts "found my window $id"
            exec xdotool set_desktop_for_window $id 4294967295
            set always_show_done 1
        }
    }
    close $fd

    #puts $list
    #puts [array names last_used]

    foreach item [lsort $list] {
        if {[regexp {^(.*)==[0-9a-f]+==(0x[0-9a-f]+)$} $item dummy name id]} {
            #puts $item
            set b [button .$id -text $name -command "activate $id" -pady 0]
            pack $b -side left
            bind $b <Control-Enter> "cover $id"
            bind $b <Leave> "uncover"

            if {[info exists last_used($id)]} {
                set b [button .bottom.$id -text $name -command "activate $id" -pady 0]
                pack $b -side top -fill x
                bind $b <Control-Enter> "cover $id"
                bind $b <Leave> "uncover"

                if {$id == $last_activated} {
                    $b config -bg #a8a0a0 -activebackground #a8a0a0
                }
            }

        }
    }
    update_button_colors
    wm geometry . +0+25
    wm geometry .bottom +0-25

    if {[winfo children .bottom] == {}} {
        wm withdraw .bottom
    } else {
        after 200 {wm deiconify .bottom}
    }
}

proc activate {id} {
    global show_cover_after last_used last_activated

    if {$id == $last_activated} {
        catch {
            exec xdotool windowminimize $id
        }
        set last_activated ""
    } else {
        catch {
            exec xdotool windowactivate $id
        }
        set last_activated $id
    }

    catch {
        destroy .cover
    }
    set old [lsort [array names last_used]]
    set last_used($id) [clock seconds]
    set show_cover_after -1

    set max 8
    set names [lsort [array names last_used]]
    if {[llength $names] > $max} {
        set times {}
        foreach i $names {
            lappend times $last_used($i)
        }
        set times [lsort -integer -decreasing $times]
        #puts $times
        set out [lindex $times $max]
        foreach i $names {
            if {$last_used($i) <= $out} {
                unset last_used($i)
            }
        }
    }

    set new [lsort [array names last_used]]

    #puts "$old == $new"
    #if {$new != $old} {
        update -force
    #}
}

set show_cover_after -1

proc cover {id} {
    global show_cover_after
    set data [exec xwininfo -id $id]
    if {[regexp {Absolute upper-left X: *([0-9]+)} $data dummy x] &&
        [regexp {Absolute upper-left Y: *([0-9]+)} $data dummy y] &&
        [regexp {Width: *([0-9]+)} $data dummy w] &&
        [regexp {Height: *([0-9]+)} $data dummy h]} {
        set geom ${w}x${h}+${x}+${y}
        catch {
            destroy .cover
        }
        toplevel .cover -bg #f07070
        wm overrideredirect .cover true
        wm geometry .cover $geom 
        set now [clock seconds]
        if {$show_cover_after < 0} {
            # change the following to $now + 2 for delayed action
            set show_cover_after [expr $now + 0]
        }
        set diff [expr $show_cover_after - $now]
        if {$diff > 0} {
            wm withdraw .cover
            after [expr $diff * 1000] "show_cover $show_cover_after"
        }
    }
}

proc uncover {} {

    catch {
        destroy .cover
    }
}

proc show_cover {n} {
    global show_cover_after
    if {$show_cover_after > 0 && $show_cover_after == $n} {
        catch {
            wm deiconify .cover
        }
    } else {
        catch {
            destroy .cover
        }
    }
}

proc set_desktop {n} {
    set n [expr $n + [exec xdotool get_desktop]]
    if {$n < 0} {
        set n 0
    }
    if {$n > 5} {
        set n 5
    }
    exec xdotool set_desktop $n
}

proc get_last_active_term {} {
    set id ""
    catch {
        set fd [open /tmp/autoraise-active-term]
        set line [gets $fd]
        set line [gets $fd]
        set id   [lindex $line 0]
        close $fd
    }
    return $id
}

proc track_last_raised_terms {} {
    global last_raised recent_raised

    set id [get_last_active_term]
    if {$id != "" && $id != $last_raised} {
        for {set i 1} {$i <= 4} {incr i} {
            if {[info exists recent_raised($i)] && $recent_raised($i) == $id} {
                break
            }
        }
        for {} {$i >= 1} {incr i -1} {
            catch {
                set recent_raised($i) $recent_raised([expr $i - 1])
            }
        }
        set recent_raised(0) $id
        set last_raised $id
        #puts ""
        #parray recent_raised
        update_button_colors
    }

    after 200 track_last_raised_terms
}

proc update_button_colors {} {
    global recent_raised

    foreach button [winfo children .] {
        if {[regexp {^.0x} $button]} {
            $button config -bg #d9d9d9 -activebackground #e9e9e9
        }
    }

    for {set i 4} {$i >= 0} {incr i -1} {
        if {[info exists recent_raised($i)]} {
            set button .$recent_raised($i)
            regsub "0x0*" $button 0x button
            set color [expr 0xff - [expr $i * 25]]
            set color #[format %02x $color]8989
            catch {$button config -bg $color -activebackground $color}
        }
    }
}

proc make_ui {} {
    wm overrideredirect . true
    wm geometry . +0-0
    set r  [button .refresh_desktop -text R -command {update -force} -pady 0]
    set b1 [button .prev_desktop -text < -command "set_desktop -1" -pady 0]
    set b2 [button .next_desktop -text > -command "set_desktop 1" -pady 0]
    pack $r  -side left -padx 0 -pady 0
    pack $b1 -side left -padx 0 -pady 0
    pack $b2 -side left -padx 0 -pady 0

    toplevel .bottom
    wm overrideredirect .bottom true
    wm geometry .bottom +0-0
}

# The last one that was "activated" by TK buttons
set last_activated ""

# The last one that was raised (by TK buttons, or by the OS's Window Manager
set last_raised ""
make_ui
update
track_last_raised_terms
