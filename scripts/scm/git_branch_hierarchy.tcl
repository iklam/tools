# Show the hierarchy of the local branches
#
# Example output:
#
# $ gitbh
# origin/master
#   master
#     1000001-archive-resolved-classes-frozen +1 -262
#     1000003-archive-lambda-forms-experimental.saved2 +1 -134
#     8293291-simplify-archive-heap-native-ptr-relocation +2
#       8292699-improve-class-printing-in-gdb.squashed +1
#         8293980-resolve-field-references-at-dumptime +2
#           1000003-archive-lambda-forms-experimental +4
# zzgone
#   0000001-archive-resolved-classes
#     1000002-archive-resolved-fields-fozen

set pat {([^ ]+) +[0-9a-z]+ \[(.*)\]}
set fd [open "|git branch -vv"]
set current {}
while {![eof $fd]} {
    set line [gets $fd]
    if {[regexp $pat $line dummy branch parentinfo]} {
        set parent $parentinfo
        set ahead 0
        set behind 0
        if {![regexp {(.*): ahead ([0-9]+), behind ([0-9]+)} $parentinfo dummy parent ahead behind]} {
            if {[regexp {(.*): behind ([0-9]+)} $parentinfo dummy parent behind]} {
                # ...
            } elseif {![regexp {(.*): ahead ([0-9]+)} $parentinfo dummy parent ahead]} {
                if {[regexp {(.*): gone} $parentinfo dummy parent]} {
                    set has(zzgone) 1
                    lappend children(zzgone) $parent
                    set p($parent) zzgone
                }
            }
        }
        set p($branch) $parent
        set a($branch) $ahead
        set b($branch) $behind
        set has($branch) 1
        set has($parent) 1
        lappend children($parent) $branch
        #puts $branch=$parent=$ahead=$behind
    } elseif {[regexp {([^ ]+) + [0-9a-z]+ } $line dummy branch]} {
        set has(zzgone) 1
        lappend children(zzgone) $branch
        set p($branch) zzgone
    } else {
        continue
    }

    if {[regexp {^[*] } $line]} {
        set current $branch
    }
}

set x $current
while {1} {
    #puts $x
    set active($x) 1
    if {[info exists p($x)]} {
        set x $p($x)
    } else {
        break
    }
}

proc dump {branch prefix} {
    global children a b current active

    if {$current == $branch} {
        puts -nonewline "==> "
    } else {
        puts -nonewline "    "
    }
    if {[info exists active($branch)]} {
        set mark "* "
    } else {
        set mark "  "
    }

    puts -nonewline $prefix$mark$branch
    if {[info exists a($branch)] && $a($branch) != 0} {
        puts -nonewline " +$a($branch)"
    }
    if {[info exists b($branch)] && $b($branch) != 0} {
        puts -nonewline " -$b($branch)"
    }
    puts ""

    if {[info exists children($branch)]} {
        set prefix "$prefix  "

        for {set n 0} {$n < 2} {incr n} {
            foreach c [lsort $children($branch)] {
                if {[info exists active($c)]} {
                    set m 0
                } else {
                    set m 1
                }
                if {$n == $m} {
                    dump $c $prefix
                }
            }
        }
    }
}

foreach branch [lsort [array names has]] {
    if {![info exists p($branch)]} {
        dump $branch ""
    }
}



