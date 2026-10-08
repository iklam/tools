set last_func ""

while {![eof stdin]} {
    set line [gets stdin]
    if {[regexp {^.[0-9]+. ([^ ].*)$} $line dummy func]} {
        #puts $func
        regsub "^virtual " $func "" func
        regsub "^static " $func "" func
        set last_func $func
    } elseif {"$line" != ""} {
        incr count($last_func) 1
        #puts $line
    }
}

foreach func [lsort [array names count]] {
    puts "$func $count($func)"
}

