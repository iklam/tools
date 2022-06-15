# Allow the user to configure whether to automatically emacs or tkdiff is automatically raised

set scripts_root [file dirname [info script]]/..
source $scripts_root/lib/xraise.tcl

wm geometry . -99+0
wm transient .

frame .e
pack .e -side top -expand yes -fill x
checkbutton .e.c -text "Emacs" -width 6 -anchor w -variable e -command "docheck e"
button .e.b -text "Raise" -width 6 -command {xraise emacs23 1}
pack .e.c .e.b -side left -fill y

frame .t
pack .t -side top -expand yes -fill x
checkbutton .t.c -text "Tkdiff" -width 6 -anchor w -variable t -command "docheck t"
button .t.b -text "Raise" -width 6 -command {xraise tkdiff 1}
pack .t.c .t.b -side left -fill y 

frame .s
pack .s -side top -expand yes -fill x
checkbutton .s.c -text "Tksvn" -width 6 -anchor w -variable s -command "docheck s"
button .s.b -text "Raise" -width 6 -command {xraise tksvn 1}
pack .s.c .s.b -side left -fill y

frame .cmd
pack .cmd -side top -expand yes -fill x
button .cmd.buf -text buf -command exec_buf
pack  .cmd.buf -side right -padx 2 -pady 1
button .cmd.gdb -text gdb -command exec_gdb
pack  .cmd.gdb -side right -padx 2 -pady 1

update idletasks
set_icon . icons8-top-menu-64.png

proc docheck {which} {
    upvar #0 $which v
    set file /tmp/autoraise-$which
    if {$v == 0} {
        exec rm -f $file
    } else {
        exec touch $file
    }
}


set terminal_pid -1
set focused_terminal_wid -1
set count 0
proc update_focused_terminal {} {
    global terminal_pid focused_terminal_wid count
    after 500 update_focused_terminal
    incr count
    set fd [open "|wmctrl -l -p"]
    set list {}
    while {![eof $fd]} {
        set line [gets $fd]
        set wid [lindex $line 0]
        set pid [lindex $line 2]

        if {[regexp emacs23@ioilinux $line] && ($count % 4) == 0} {
            if {[catch {
                set data [exec xwininfo -id $wid -wm | grep -v Sticky]
            }]} {
                continue
            }
            if {[regexp "Window state:\[\n\r\t \]*Focused" $data]} {
                #puts doit
                catch {
                    set socket [socket localhost 9989]
                    puts $socket raiseifhidden
                    close $socket
                }
            }
            continue
        }


        if {$terminal_pid == -1} {
            catch {
                set data [exec ps -fp $pid]
                if {[regexp gnome-terminal-server $data]} {
                    set terminal_pid $pid
                }
            }
        }
        if {$pid != $terminal_pid} {
            continue
        }

        set data [exec xwininfo -id $wid -wm]
        if {[regexp "Window state:\[\n\r\t \]*Focused" $data]} {
            if {$focused_terminal_wid != $wid} {
                set focused_terminal_wid $wid
                puts "Focused terminal changed to: $line"
                set wfd [open /tmp/autoraise-active-term w+]
                puts $wfd "Currently active gnome terminal window ID is $wid\n$line"
                close $wfd
            }
            break
        }
    }
    catch {
        close $fd
    }
}

proc exec_gdb {} {
    global scripts_root
    catch {
        exec bash -c "nohup wish $scripts_root/myide/gdbwatch.tcl < /dev/null > /dev/null 2> /dev/null &"
    }
}

proc exec_buf {} {
    catch {
        exec bash -c {nohup wish /home/iklam/jdk/proj/ioisvn/scripts/emacs_buf_watch.tcl < /dev/null > /dev/null 2> /dev/null &}
    }
}

update_focused_terminal
