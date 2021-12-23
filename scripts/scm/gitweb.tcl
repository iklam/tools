# find the github URL of the given file at the current version and also copy that into the X clipboard.
# Example:
#   https://github.com/iklam/jdk/blame/a1c850b267dc6892aff8ea8b5830f8cda44a8ed8/ADDITIONAL_LICENSE_INFO
set file    [lindex $argv 0]
set linenum [lindex $argv 1]
set diff    [lindex $argv 2]
set quit    [lindex $argv 3]

# Emacs passes "line 123"
regsub {^[Ll]ine } $linenum "" linenum

#puts $file
set line ""
regexp {(.*):([0-9]+)$} $file dummy file line

if {[file pathtype $file] != "absolute"} {
    set file [file normalize [pwd]/$file]
}

set d $file
while {$d != "/"} {
    if {[file exists $d/.git]} {
        set git 1
        break
    } else {
        set d [file dir $d]
    }
    #puts $d
}

if {![info exists git]} {
    puts "$file is not in git"
    exit 1
}

set file [string range $file [expr [string len $d] + 1] end]
cd $d

if {"$diff" == "-tkdiff"} {
    # Open a tkdiff window to show the diff at the give linenum
    set fd [open "|git blame $file" r]
    set num 0
    while {![eof $fd]} {
        set line [gets $fd]
        incr num 1
        if {$num == $linenum} {
            if {[regexp {^([0-9a-f]+) } $line dummy hash]} {
                set cmdline "tkdiff -r ${hash}~1 -r $hash $file"
                puts "found version $hash at line $num"
                if {"$quit" == "quit"} {
                    eval exec "nohup $cmdline > /dev/null 2> /dev/null &"
                } else {
                    catch {eval exec $cmdline 2>@ stdout >@ stdout}
                }
            }
            exit
        }
    }
} else {
    catch {
        set fd [open "|git log $file" r]
        while {![eof $fd]} {
            set line [gets $fd]
            if {[regexp {^commit ([0-9a-f]+)} $line dummy hash]} {
                set url https://github.com/iklam/jdk/blame/$hash/$file
                if {"$linenum" != ""} {
                    append url "#L${linenum}"
                }
                break;
            }
        }
        close $fd
    }

    if {[info exists url]} {
        set fd [open "|xclip" w+]
        puts -nonewline $fd $url
        close $fd
        puts $url
    } else {
        puts "Cannot find URL for [pwd]/$file"
    }
}
