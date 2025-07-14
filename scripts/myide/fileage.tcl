set t [file mtime [lindex $argv 0]]
set now [clock seconds]

set diff [expr $now - $t]
set s [expr $diff % 60]; set diff [expr $diff / 60]
set m [expr $diff % 60]; set diff [expr $diff / 60]
set h [expr $diff % 24]; set diff [expr $diff / 24]
set d $diff


set info [format "%02d:%02d:%02d" $h $m $s]

if {$d > 0} {
    set info "$d day(s) $info"
}
puts $info

