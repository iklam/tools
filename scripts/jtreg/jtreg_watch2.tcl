set results ""
set prefix ""

while {![eof stdin]} {
    set line [gets stdin]
    if {[regexp {Test results: } $line]} {
        regsub -all {[=<>]} $line "" line
        append results $prefix$line
        set prefix \n
    }
    puts $line
}

puts ======================================================================
puts $results
if {[regexp -nocase ((failed)|(error)) $results]} {
    exit 1
} else {
    exit 0
}
