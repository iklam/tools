#! /bin/wish
# Allow the user to configure whether to automatically emacs or tkdiff is automatically raised
#
# This also runs the server for ./distcc.tcl and ../jtreg/jtreg_dist.tcl (at port 9989)

set scripts_root [file dirname [info script]]/..
source $scripts_root/lib/xraise.tcl

wm geometry . -85+0
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
                    set socket [socket localhost 9990]
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
    global scripts_root
    if {[catch {
        exec bash -c "nohup wish $scripts_root/myide/emacs_buf_watch.tcl < /dev/null > /dev/null 2> /dev/null &"
    } err]} {
        puts $err
    }
}

# ~/.distcc.config.tcl
#
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

proc distcc_init {} {
    global distcc_selected distcc_order distcc_cpus distcc_active

    uplevel #0 source ~/.distcc.config.tcl
 
    foreach host $distcc_order {
        set distcc_selected($host) 1
        set distcc_active($host) 0
    }
    socket -server handle_distcc_request 9989
}

# We have more concurrent compiler processes than available nodes. Put these in an FIFO queue
set waiting_distcc_fds {}

# addr and port are ignored
proc handle_distcc_request {fd addr port} {
    global waiting_distcc_fds distcc_cpuneed distcc_cmdline

    # A value of 100 means this client needs 1 CPU
    set distcc_cpuneed($fd) [gets $fd]
    set distcc_cmdline($fd) [gets $fd]
    
    if {![try_satisfy_distcc_request $fd]} {
        lappend waiting_distcc_fds $fd
    }
}

proc try_satisfy_distcc_request {fd} {
    global distcc_cpus distcc_order distcc_active distcc_selected distcc_cpuneed distcc_host_slot_used distcc_fd_to_slot

    set hosts {}
    foreach host $distcc_order {
        if {$distcc_selected($host)} {
            lappend hosts $host
        }
    }

    if {$hosts == {}} {
        set host [lindex $distcc_order 0]
        set hosts $host
        set distcc_selected($host) 1
    }

    # Find the host with the lowest load
    set found {}
    set lowest_load 99999999.0
    foreach host $hosts {
        if {$distcc_active($host) >= $distcc_cpus($host) * 100} {
            continue
        }

        set load 1.0
        catch {
            set load [expr $distcc_active($host).0 / $distcc_cpus($host).0]
        }
        #puts $host=$distcc_active($host)=$load,max=$lowest_load
        if {$lowest_load > $load} {
            set lowest_load $load
            set found $host
        }
    }

    set host $found

    if {$host == {}} {
        # Give up for now. Retry later when some jobs have finished
        return 0
    }

    # Each client is given a logical "slot" on a given host. This allows
    # clients to create directories like /tmp/$host.$slot/ to avoid writing
    # over each other's files. This is used by jtreg_dist.tcl
    for {set slot 0} {1} {incr slot} {
        if {![info exists distcc_host_slot_used($host,$slot)]} {
            set distcc_host_slot_used($host,$slot) 1
            set distcc_fd_to_slot($fd) $slot
            #puts ADD-$host-$slot
            break
        }
    }

    puts $fd $host
    puts $fd $slot
    flush $fd
    incr distcc_active($host) $distcc_cpuneed($fd)
    fileevent $fd readable [list do_distcc_fileevent $fd $host]

    #parray distcc_active
    #update_hosts_stats

    return 1
}

# fd is a client that has already been scheduled onto the host. We
# get called whenever we get an incomming message on fd, or when fd
# is EOF. The latter is more likely (the client has terminated)
proc do_distcc_fileevent {fd host} {
    global distcc_active waiting_distcc_fds distcc_cpuneed distcc_host_slot_used distcc_fd_to_slot
    global distcc_cmdline

    catch {
        gets $fd
    }
    if {[eof $fd]} {
        incr distcc_active($host) -$distcc_cpuneed($fd)
        unset distcc_cpuneed($fd)
        unset distcc_cmdline($fd)
        # Free the slot, so it can be reused by future clients
        set slot $distcc_fd_to_slot($fd)
        #puts DELETE-$host-$slot
        unset distcc_host_slot_used($host,$slot)
        #puts OK
        unset distcc_fd_to_slot($fd)
        catch {
            close $fd
        }
        if {[llength $waiting_distcc_fds] > 0} {
            # Dispatch the next job
            set fd [lindex $waiting_distcc_fds 0]
            if {[try_satisfy_distcc_request $fd]} {
                #puts "redispatch $fd"
                set waiting_distcc_fds [lrange $waiting_distcc_fds 1 end]
            }
        }
    } else {
        fileevent $fd readable [list do_distcc_fileevent $fd $host]
    }
    #parray distcc_active
    #update_hosts_stats
}

set lasttime 0
proc update_host_selection {} {
    global lasttime distcc_selected
    set file ~/.distcc.selected
    set time [file mtime $file]
    if {$time > $lasttime} {
        set lasttime $time
        source  ~/.distcc.selected
        parray distcc_selected
    }
    after 1000 update_host_selection
}



update_focused_terminal
distcc_init
update_host_selection
