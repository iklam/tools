# I need to use this because gnome-panel no longer works with the new ubuntu Gnome desktop.

set cur_desktop -1
set always_show_done 0

proc update {args} {
    #puts update
    global cur_desktop always_show_done last_used
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
            set b [button .$id -text $name -command "activate $id"]
            pack $b -side left
            bind $b <Control-Enter> "cover $id"
            bind $b <Leave> "uncover"

            if {[info exists last_used($id)]} {
                set b [button .bottom.$id -text $name -command "activate $id"]
                pack $b -side top -fill x
                bind $b <Control-Enter> "cover $id"
                bind $b <Leave> "uncover"
            }

        }
    }
    wm geometry . +43+25
    wm geometry .bottom +43-0

    if {[winfo children .bottom] == {}} {
        wm withdraw .bottom
    } else {
        after 200 {wm deiconify .bottom}
    }
}

proc activate {id} {
    global show_cover_after last_used
    catch {
        exec xdotool windowactivate $id
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
        puts $times
        set out [lindex $times $max]
        foreach i $names {
            if {$last_used($i) <= $out} {
                unset last_used($i)
            }
        }
    }

    set new [lsort [array names last_used]]

    #puts "$old == $new"
    if {$new != $old} {
        update -force
    }
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

proc make_ui {} {
    wm overrideredirect . true
    wm geometry . +0-0
    set r  [button .refresh_desktop -text R -command {update -force}]
    set b1 [button .prev_desktop -text < -command "set_desktop -1"]
    set b2 [button .next_desktop -text > -command "set_desktop 1"]
    pack $r  -side left
    pack $b1 -side left
    pack $b2 -side left

    toplevel .bottom
    wm overrideredirect .bottom true
    wm geometry .bottom +0-0
}

make_ui
update
