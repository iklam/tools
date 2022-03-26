# jbs_status.tcl --
#
# Currently, this script does only this (which I do like a million times a day)
# - get a JBS bug ID from the X clipboard
# - print out the full URL for this JBS issue
#
# TODO:
# Also print out if the bug has been resolved, etc.

set N {[0-9]}
set pat $N$N$N$N$N$N$N

if {![regexp $pat $argv bugid] && ![regexp $pat [exec xclip -o] bugid]} {
    puts "Please specify bugid in command-line or clipboard"
}

set url "https://bugs.openjdk.java.net/browse/JDK-$bugid"
puts ""
puts "$url"
puts ""

set fd [open "|xclip -i" w+]
puts -nonewline $fd $url
close $fd


