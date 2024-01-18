proc geomean {list} {
    expr pow([join $list *],1./[llength $list])
}

puts [geomean $argv]
