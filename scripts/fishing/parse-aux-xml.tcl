#<Name>VALUE</Name>

#<Name>SLOPE</Name>
#<Name>DEPTH_ZONE</Name>
#<Name>SUBSTRATE</Name>

#<Name>SUBST_DESC</Name>
#<Name>FULL_DESC</Name>

set data [read stdin]
regsub -all "<Row index=" $data \uffff data
set n 0
foreach part [split $data \uffff] {
    incr n
    if {$n == 1} {
        continue
    }
    regsub -all " *<F>" $part "" part
    regsub -all "</F>\n" $part ", " part
    regsub {^[^>]*>.} $part "" part
    regsub {^[0-9]+, } $part "" part
    regsub {^([0-9]+), [0-9]+} $part "\\1" part
    regsub {, ([A-Za-z ]+),.*} $part ", \"\\1\")," part
    regsub {^([0-9]), } $part "  \\1, " part
    regsub {^([0-9][0-9]), } $part " \\1, " part
    puts "            new Info($part"
}
