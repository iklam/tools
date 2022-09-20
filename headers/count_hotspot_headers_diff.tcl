proc load {file var} {
    upvar #0 $var table
    global all_headers

    set reporoot ""

    set fd [open $file]
    while {![eof $fd]} {
        set line [gets $fd]
        if {[regexp {[0-9]+ +([0-9]+) +[0-9]+ (.*)} $line dummy count header]} {
            if {[regexp {(.*)src/hotspot/share/runtime/globals.hpp} $header dummy reporoot]} {
                break
            }
        }

    }
    close $fd


    set fd [open $file]
    while {![eof $fd]} {
        set line [gets $fd]
        if {[regexp {[0-9]+ +([0-9]+) +[0-9]+ (.*)} $line dummy count header]} {
            if {$reporoot != ""} {
                regsub $reporoot $header "" header
            }
            regsub {.*/src/hotspot/} $header "src/hotspot/" header
            regsub {.*/(support/modules_include/)} $header "OUTDIR/\\1" header
            regsub {.*/(hotspot/variant-[^/]+/)} $header "OUTDIR/\\1" header
            set table($header) $count
            set all_headers($header) 1
        }
    }
    close $fd
}


load [lindex $argv 0] before
load [lindex $argv 1] after

foreach header [array names all_headers] {
    set old_count 0
    set new_count 0
    catch {set old_count $before($header)}
    catch {set new_count  $after($header)}

    set diff [expr $new_count - $old_count]
    if {$diff != 0} {
        puts [format {%6d %s} $diff $header]
    }
}
