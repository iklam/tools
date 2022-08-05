set csv 1
if {[lindex $argv 0] == "-n"} {
    set compares_num [lindex $argv 1]
    set csv 0
} else {
    set compares_num [lindex $argv 0]
}
if {"$compares_num" == ""} {
    set compares_num 2
}

if {$csv} {
    puts "Left,Right,Left,Right"
}

set row 0
set c 0
while {![eof stdin]} {
    set line [gets stdin]
    if {[regexp {([0-9,]+) +instructions} $line dummy instr]} {
        regsub -all , $instr "" instr
        set i($c) $instr
        #puts $instr
    } elseif {[regexp {^ *([0-9.]+) .*seconds time elapsed } $line dummy elapsed]} {
        #puts $elapsed--$line
        set e($c) [expr $elapsed * 1000]
        incr c
        set out ""
        if {$c >= $compares_num} {
            for {set x 0} {$x < $c} {incr x} {
                append out $i($x),
                set all($row,$x) $i($x)
            }
            for {set x 0} {$x < $c} {incr x} {
                append out [format %.3f $e($x)],
                set all($row,[expr $x + $compares_num]) $e($x)
            }
            if {$csv} {
                puts $out
            }
            incr row
            set c 0
        }
    } elseif {[regexp {Performance counter stats for .(.*/bin/java[^ ]* .*). .([0-9]+) runs} $line dummy args loops]} {
        if {![info exists comment1]} {
            set comment1 "Left : perf stat -r $loops $args"
        } elseif {![info exists comment2]} {
            set comment2 "Right: perf stat -r $loops $args"
        }
    }
}

proc gmean {L} {
    expr pow([join $L *],1./[llength $L])
}

proc geom_column {i} {
    global row all
    set list {}
    for {set r 0} {$r < $row} {incr r} {
        lappend list $all($r,$i)
    }
    if {[llength $list] > 0} {
        return [gmean $list]
    } else {
        return 0
    }
}

proc calc_chart {which old new} {
    global row all chart
    set max 0

    for {set r 0} {$r <= $row} {incr r} {
        set o $all($r,$old)
        set n $all($r,$new)
        set diff [expr abs($o - $n)]
        if {$max < $diff} {
            set max $diff
        }
    }
    set width 5
    for {set r 0} {$r <= $row} {incr r} {
        set o $all($r,$old)
        set n $all($r,$new)
        set bars ""

        if {$max > 0} {
            set diff [expr round((0.0 + abs($o - $n)) / $max * $width)]
            if {$o > $n} {
                set sign -
            } else {
                set sign +
            }
            for {set i 0} {$i < $diff} {incr i} {
                append bars $sign
            }
            if {$o > $n} {
                set bars [format "%${width}s%-${width}s" "" $bars]
            } else {
                set bars [format "%${width}s%${width}s" $bars ""]
            }
            set bars " $bars "

            if {$which == 0} {
                set w [expr [string len $max] + 1]
                set extra [format "%${w}d" [expr int($n - $o)]]
            } else {
                set extra [format "%7.3f"  [expr $n - $o]]
            }
            set bars " ($extra)$bars"
        }

        set chart($r,$which) $bars
    }
}

for {set c 0} {$c < 2 * $compares_num} {incr c} {
    set all($row,$c) [geom_column $c]
}

if {$compares_num == 2} {
    calc_chart 0 0 1
    calc_chart 1 2 3
}

if {[info exists comment1]} {
    puts $comment1
}
if {[info exists comment2]} {
    puts $comment2
}
for {set r 0} {$r <= $row} {incr r} {
    set out ""
    for {set c 0} {$c < 2 * $compares_num} {incr c} {
        set n $all($r,$c)
        if {$c < $compares_num} {
            set text [format %12d [expr int($n)]]
            if {$compares_num == 2 && $c == 1} {

                if 0 {
                    if {$all($r,1) < $all($r,0)} {
                        append text " - "
                    } else {
                        append text "   "
                    }
                } else {
                    append text $chart($r,0)
                }
            }
        } else {
            set text [format %10.3f $n]
            if {$compares_num == 2 && $c == 3} {
                if 0 {
                    if {$all($r,3) < $all($r,2)} {
                        append text " - "
                    } else {
                        append text "   "
                    }
                } else {
                    append text $chart($r,1)
                }
            }
        }
        append out $text
    }

    if {$r < $row} {
        puts "[format %4d: [expr $r+1]] $out"
    } else {
        puts "[format %5s  ""] $out"
    }
    if {$r == $row - 1} {
        puts ============================================================
    }
}

if {$compares_num == 2 && $row > 0} {
    set int_delta  [expr int($all($row,1) - $all($row,0))]
    set int_perc   [expr $int_delta / $all($row,0) * 100]
    set time_delta [expr $all($row,3) - $all($row,2)]
    set time_perc  [expr $time_delta / $all($row,2) * 100]

    puts "instr delta = [format {%12d    %7.4f%%} $int_delta $int_perc]"
    puts "time  delta = [format {%12.3f ms %7.4f%%} $time_delta $time_perc]"
}
