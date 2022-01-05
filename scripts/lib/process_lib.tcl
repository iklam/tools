# Generic process dispatcher

# on my machine, don't run more than 48 parallel processes
set g_proc_config(max) 48

proc process_dispatch {handle cmdline {callback {}}} {
    global g_proc_handles g_proc_pending g_proc_config g_proc_callbacks g_proc_output

    if {[info exists g_proc_handles($handle)]} {
        error "handle $handle already exists"
    }

    if {[array exists g_proc_handles] && [array size g_proc_handles] >= $g_proc_config(max)} {
        lappend g_proc_pending [list $handle $cmdline $callback]
    } else {
        set fd [open "|$cmdline" r]
        fconfigure $fd -blocking false
        fileevent $fd readable [list process_fileevent $handle]
        set g_proc_handles($handle) $fd
        set g_proc_callbacks($handle) $callback
        set g_proc_output($handle) ""
    }
}

proc process_fileevent {handle} {
    global g_proc_handles g_proc_callbacks g_proc_output g_proc_done g_proc_statechanged g_proc_pending g_proc_config

    set fd $g_proc_handles($handle)
    while {![eof $fd]} {
        set line [gets $fd]
        if {[fblocked $fd] || [eof $fd]} {
            break;
        }
        lappend g_proc_output($handle) $line
    }
    if {[eof $fd]} {
        close $fd
        set callback $g_proc_callbacks($handle)

        unset g_proc_handles($handle)
        unset g_proc_callbacks($handle)

        if {$callback != {}} {
            # This is async mode -- the app will not call process_join. Instead, it relies on $callback to
            # inform it of the results of the program
            set output $g_proc_output($handle)
            unset g_proc_output($handle)
            uplevel #0 $callback $handle [list $output]
        } else {
            # This is synchronous mode. The app will call process_join to block and wait for the result
            # of the program.
            set g_proc_done($handle) 1
            set g_proc_statechanged 1

            if {[info exists g_proc_pending] && [llength $g_proc_pending] > 0} {
                if {![array exists g_proc_handles] || [array size g_proc_handles] < $g_proc_config(max)} {
                    set item [lindex $g_proc_pending 0]
                    set g_proc_pending [lrange $g_proc_pending 1 end]
                    process_dispatch [lindex $item 0] [lindex $item 1] [lindex $item 2]
                }
            }
        }
    }
}

proc process_join {} {
    global g_proc_handles g_proc_output g_proc_done g_proc_statechanged

    while 1 {
        if {[array exists g_proc_done] && [array size g_proc_done] > 0} {
            set handle [lindex [array names g_proc_done] 0]
            unset g_proc_done($handle)
            set result [list $handle $g_proc_output($handle)]
            unset g_proc_output($handle)

            return $result
        }

        if {[array exists g_proc_handles] && [array size g_proc_handles] > 0} {
            vwait g_proc_statechanged
            continue
        }

        # No more process to run
        catch {unset g_proc_output}
        return {}
    }
}
