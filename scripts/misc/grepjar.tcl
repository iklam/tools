set pattern [lindex $argv 0]

foreach zip [lrange $argv 1 end] {
    set lines [exec jar tf $zip]
    foreach line [lsort [split $lines \n]] {
        if {[regexp $pattern $line]} {
            puts "$zip: $line"
        }
    }
}
