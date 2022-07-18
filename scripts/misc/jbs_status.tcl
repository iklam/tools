# jbs_status.tcl --
#
# Currently, this script does only this (which I do like a million times a day)
# - get a JBS bug ID from the X clipboard
# - print out the full URL for this JBS issue
# - Also print out if the bug has been resolved, etc.

set N {[0-9]}
set pat $N$N$N$N$N$N$N

if {![regexp $pat $argv bugid] && ![regexp $pat [exec xclip -o] bugid]} {
    puts "Please specify bugid in command-line or clipboard"
    exit 1
}

set url "https://bugs.openjdk.java.net/browse/JDK-$bugid"
puts ""
puts "$url"
puts ""

# -t means copy the bug title into the clipboard
# otherwise copy the URL.
if {[regexp {[-]t} $argv]} {
    set copy_title 1
} else {
    set copy_title 0
    set fd [open "|xclip -i" w+]
    puts -nonewline $fd $url
    close $fd
}

flush stdout

if {[catch {
    set data [exec wget -O - -q $url]
    if {[regexp {<title>([^<]+)</title>} $data dummy  title]} {
        regsub { - Java Bug System} $title "" title
        regsub {^[^\]]+\] } $title "" title
        set t "$bugid: $title"
        puts "    Title:              $t"
        if {$copy_title} {
            set fd [open "|xclip -i" w+]
            puts -nonewline $fd $t
            close $fd
        }
    }

    regsub {<h4 class="toggle-title">Description</h4>.*} $data "" data
    regsub -all {<[^>]+>} $data "" data
    regsub "\n *Description.*" $data "" data
    regsub .*Type: $data Type: data
    #regsub -all "\[\r\n\t \]+" $data " " data

    set sep ""
    foreach n [split $data \n] {
        if {[regexp : $n]} {
            puts -nonewline "$sep    [format %-20s [string trim $n]]"
            set sep \n
        } else {
            foreach w $n {
                puts -nonewline "$w "
            }
        }
    }
    puts ""
} err]} {
    puts "Cannot get url $err"
}


