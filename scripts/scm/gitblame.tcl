proc get_log {hash} {
    global gitlog log_width blank

    if {![info exists gitlog($hash)]} {
        set data [exec git log -1 $hash]
        set msg ""
        set N {[0-9]}
        if {![regexp "    ($N$N$N$N$N$N$N: \[^\n\]*)" $data dummy msg]} {
            regexp {Initial load} $data msg
        }
        #if {[regexp 8197925 $data]} {  puts =$msg== }

        set msg "[string trim $msg]$blank"
        set msg [string range $msg 0 $log_width]
        set gitlog($hash) $msg

        #if {[regexp 8197925 $data]} {  puts =$msg== }
        #if {[regexp 8197925 $data]} exit
    }
    return $gitlog($hash)
}

set log_width 40
set blank [format "%${log_width}s " ""]
set file [lindex $argv 0]
set fd [open "|git blame $file" r]
cd [file dirname $file]

set pat {^([0-9a-f]+) +[^ ]+ +[\(][^\)]+[\)] (.*)}
set last_hash {}
while {![eof $fd]} {
    set line [gets $fd]
    if {[regexp $pat $line dummy hash code]} {
        if {$last_hash == $hash && 0} {
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
