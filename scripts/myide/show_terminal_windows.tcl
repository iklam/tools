# Raise all the terminals of the current repo
#
# This can be activated by the "wins" alias in ./bashrc.sh
#
# alias wins='tclsh $IOIGIT/scripts/myide/show_terminal_windows.tcl $GNOME_TERNIMAL_NAME'
#
# wins    = show all terminals of the current repo
# wins -h = show all terminals of the current repo; and hide all other terminals
source [file dirname [info script]]/../lib/common.tcl

set hide_others [pop_arg h]

set title [lindex $argv 0]

if {"$title" == ""} {
    set data ""
    catch {
        set data [string trim [exec cat /tmp/autoraise-active-term]]
    }
    #puts $data
    set hostname ioilinux2
    if {[regexp "(0x\[0-9a-f\]+).*$hostname (.*)" $data dummy active title]} {
        puts "found last active win $active -- $title"
        if 1 {
            # ioi -- wh's wrong with doing this???
            catch {
                exec wmctrl -i -a $active
                exit
            }
        }
    } else {
        puts "window title not specified"
        exit
    }
}

if {![info exists active]} {
    set active [string trim [exec xprop -root _NET_ACTIVE_WINDOW]]
}

if {[regexp {0x[0-9a-f]+$} $active active]} {
    set fd [open "|wmctrl -p -l"]
    set list {}
    while {![eof $fd]} {
        set line [gets $fd]
        set pattern "( $title)|(bufie)"
        if {[regexp {^(0x[0-9a-f]+) } $line dummy id]} {
            if {[regexp $pattern $line]} {
                puts $line
                exec wmctrl -i -a $id
            } elseif {$hide_others} {
                set pid [lindex $line 2]

                if {![info exists should_hide($pid)]} {
                    set h 0
                    catch {
                        set data [exec ps $pid]
                        if {[regexp {gnome-terminal-server} $data]} {
                            set h 1
                        }
                    }
                    set should_hide($pid) $h
                }

                if {$should_hide($pid)} {
                    puts HIDE=$id=$line
                    catch {
                        exec xdotool windowminimize [expr $id + 0]
                    }
                }
            }
        }
    }

    if {[info exist id] && $id != $active} {
        exec wmctrl -i -a $active
    }
}
