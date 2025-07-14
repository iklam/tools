# cycle_current_repo_terminals.tcl
#
# Cycle between the terminals that are working on the current repo (as specified by /tmp/autoraise-active-term)

if {[catch {
    set fd [open /tmp/autoraise-active-term]
    set line [gets $fd]
    set line [gets $fd]
    set cur_id   [lindex $line 0]
    set cur_repo [lindex $line end]
    close $fd
} err]} {
    puts $err
    exit
}

puts $cur_id
puts $cur_repo

set list {}
set fd [open "|xwininfo -root -tree"]
while {![eof $fd]} {
    set line [gets $fd]
    if {[regexp {(Gnome-terminal)} $line]} {
        #puts $line
        if {[regexp {(0x[0-9a-f]+).*[+]([0-9]+)[+]} $line dummy id xpos]} {
            set xpos [format %08x $xpos]
            set data [exec xprop -id $id]
            if {[regexp {_NET_WM_DESKTOP.CARDINAL. = ([0-9]+)} $data dummy desktop] &&
                [regexp {_NET_WM_ICON_NAME.UTF8_STRING. = \"([^\"]+)\"} $data dummy name]} {

                if {$name == $cur_repo} {
                    set last_id $id
                }
            }
        }
    }
}

# Show the window at the very bottom of the window stack
if {[info exists last_id] && $last_id != $cur_id} {
    exec xdotool windowactivate $last_id
}


