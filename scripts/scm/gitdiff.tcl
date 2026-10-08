# Print all NEW lines in the diff, prefixed with the file name, so we can easily grep for
# code that we just wrote.
#
#
# tclsh ${IOIGIT}/scripts/scm/gitdiff.tcl | grep in_aot_cache

set fd [open "|git diff $argv" r]
set last ""
while {![eof $fd]} {
    set line [gets $fd]

    if {[regexp {^[+-][+-][+-] [ab]/(.*)} $line dummy file]} {
        set last $file
    } elseif {[regexp {^[+](.*)} $line dummy line]} {
        puts "$last:$line"
    }
}

close $fd
