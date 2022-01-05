# gitblame.tcl
#
# Annotate "git blame" with JDK bug IDs.
#
# This works only with the JDK repos. It requires that the log messages
# follow the JDK convention of "NNNNNNN: bug synopsis"
proc get_log {hash} {
    global gitlog log_width blank

    if {![info exists gitlog($hash)]} {
        if {$hash == "00000000"} {
            set msg "Not Committed Yet"
        } else {
            set data [exec git log -1 $hash]
            set msg ""
            set N {[0-9]}
            if {![regexp "    ($N$N$N$N$N$N$N: \[^\n\]*)" $data dummy msg]} {
                if {![regexp {Initial load} $data msg]} {
                    regexp "\n    (\[^\n\]+)" $data msg
                }
            }
        }
        set msg "[string trim $msg]$blank"
        set msg [string range $msg 0 $log_width]
        set gitlog($hash) $msg
    }
    return $gitlog($hash)
}

set log_width 40
set blank [format "%${log_width}s " ""]

if {[lindex $argv 0] == "-v"} {
    set verbose 1
    set file [lindex $argv 1]
} else {
    set verbose 0
    set file [lindex $argv 0]
}

set fd [open "|git blame $file" r]
cd [file dirname $file]

set pat {^([0-9a-f]+) +[^ ]+ +[\(][^\)]+[\)] (.*)}
set pat2 {^([0-9a-f]+) +[\(][^\)]+[\)] (.*)}
set last_hash {}
while {![eof $fd]} {
    set line [gets $fd]
    if {[regexp $pat  $line dummy hash code] ||
        [regexp $pat2 $line dummy hash code]} {
        if {$last_hash == $hash && !$verbose} {
            puts "$blank | $code"
        } else {
            puts "[get_log $hash] | $code"
        }
        set last_hash $hash
    } else {
        puts $line
    }
}
close $fd
