set pattern [lindex $argv 0]

set fd [open "|git diff" r]
set last ""
while {![eof $fd]} {
    set line [gets $fd]

    if {[regexp {^[+-][+-][+-] [ab]/(.*)} $line dummy file]} {
        set last $file
    } elseif {[regexp {^[+](.*)} $line dummy line]} {
        puts "$last: $line"
    }
}

close $fd
