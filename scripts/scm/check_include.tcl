# In bash:
#
# function gitcppchanges () {
#    git diff $1 | grep '^[+][+][+] b/' | sed -e 's/^... b.//g'  | grep '[.].pp'
# }
# gitcppchanges 8d0975a27d826f7aa487a612131827586abaefd5
#
#
# tclsh $IOIGIT/scripts/scm/check_include.tcl $(gitcppchanges 8d0975a27d826f7aa487a612131827586abaefd5 | sort)

set env(LC_COLLATE) C

foreach file $argv {
    set fd [open $file]
    set list ""

    set out [open /tmp/include.orig w+]
    while {![eof $fd]} {
        set line [gets $fd]
        if {[regexp {^#include} $line] && ![regexp precompiled.hpp $line]} {
            puts $out $line
        }
    }
    close $fd
    close $out
    exec bash -c {cat /tmp/include.orig | sort | uniq > /tmp/include.uniq}
    puts "---- $file"
    if {[catch {
        exec diff -q /tmp/include.orig /tmp/include.uniq
    }]} {
        catch {exec $env(IOIGIT)/scripts/scm/tkdiff /tmp/include.orig /tmp/include.uniq}
    }
}
