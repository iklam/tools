# A library function for raising an X window

catch {
    # For the "id process parent" command
    package require Tclx
}

proc xraise {name {force 0}} {
    global last

    if {!$force} {
        if {$name == "emacs23" && ![file exists /tmp/autoraise-e]} {
            return 0
        }
        if {$name == "tkdiff" && ![file exists /tmp/autoraise-t]} {
            return 0
        }
        if {$name == "tksvn" && ![file exists /tmp/autoraise-s]} {
            return 0
        }
    }

    if {![info exists last($name)]} {
        set last($name) 1000000
    }

    set list [get_all_wm_windows $name]
    if {$list == {} && $name == "emacs23"} {
        set name the_emacs
        set list [get_all_wm_windows $name]
    }
    #puts ==$list==
    incr last($name)
    set max [llength $list]
    if {$last($name) >= $max} {
        set last($name) 0
    }

    catch {exec wmctrl -i -a [lindex $list $last($name)]}
        return 1
}

proc get_all_wm_windows {{name .}} {
    set fd [open "|wmctrl -l"]
    set list {}
    while {![eof $fd]} {
        set line [gets $fd]
        if {[regexp $name $line] && [regexp {^(0x[0-9a-f]+) } $line dummy id]} {
            lappend list $id
        }
    }
    close $fd

    return $list
}

proc DOESNT_WORK_get_active_window {} {
    # If autoraise.tcl is running in the background, it will track the currently
    # active gnome terminal window for us.
    set f /tmp/autoraise-active-term
    if {[file exists $f]} {
        set fd [open $f]
        set data [read $fd]
        close $fd
        if {[regexp {active gnome terminal window ID is (0x[0-9a-f]+)} $data dummy id]} {
            return $id
        }
    }

    foreach id [get_all_wm_windows] {
        set data [exec xwininfo -id $id -wm]
        if {[regexp "Window state:\[\n\r\t \]*Focused" $data]} {
            return $id
        }
    }
    return ""
}

# line needs to be +123, etc.
proc edit_in_emacs {file {line {}}} {
    global env

    ## TODO - factor this out
    #if {![file exists $file] && [info exists env(NO_NEW_FILES)]} {
    #    # first try to see if we are called from a bash shell
    #    set curdir get_curdir
    #
    #    puts "not found $file"
    #    return
    #}
    ## TODO - end

    #set active_win [get_active_window]
    set raised [xraise emacs23]
    if {[info exists env(REVERT)]} {
        exec emacsclient -n --eval  "(progn (revert-files \"$file\") (find-file \"$file\") )" &
        if {$line != {}} {
            exec emacsclient -n $line $file &
        }
    } else {
        if {$line == {}} {
            exec emacsclient -n $file &
        } else {
            exec emacsclient -n $line $file &
        }
    }

    return 0
}

proc set_icon {w iconfile} {
    global env

    if {![file exist iconfile]} {
        set iconfile $env(IOISVN)/scripts/icons/$iconfile
    }
    #puts $iconfile
    #puts [winfo id $w]--[wm frame $w]
    #set id [winfo id $w]
    #set id [wm frame $w]
    set id [get_wm_window_id $w]
    #puts ==$id==
    if {$id != ""} {
        exec $env(HOME)/bin/xseticon -id $id $iconfile
    }
}

proc get_wm_window_id {w} {
    set wmid ""

    set id [wm frame $w]
    if {$id == 0x0} {
        error "Cannot call this when $w is not mapped!"
    }
    if {[catch {
        set data [exec xwininfo -id $id -children]
        regexp "1 child:\[ \r\n\t\]*(0x\[0-9a-f\]+)" $data dummy wmid
    } err]} {
        puts $err
    }
    if {"$wmid" == ""} {
        puts "Cannot find window manager id for $w"
    }
    return $wmid
}


proc focus_me {w} {
    #puts focus_me
    set id [get_wm_window_id $w]
    if {$id != ""} {
        catch {
            #puts "wmctrl -i -a $id"
            exec wmctrl -i -a $id
        }
    }
}
