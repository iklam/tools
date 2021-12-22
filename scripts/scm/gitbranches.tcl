# Look at all the branches of all the repos and sort them by time, so I know what I am working on

set locations {/jdk2/*/open}

set maxlen 0
foreach pat $locations {
    set dirs [glob -nocomplain $pat]
    foreach dir $dirs {
        if {[file exists $dir/.git]} {
            set PWD [pwd]
            if {[catch {
                cd $dir
                foreach b [split [exec git branch] \n] {
                    set b [string trim $b]
                    if {$b != ""} {
                        set iscurrent [regsub {^[*] } $b "" b]
                        #if {"$b" == "master" || "$b" == "lworld"} {
                        #    continue
                        #}
                        set log [exec git log -1 $b]
                        set date 0
                        catch {
                            regexp "Date:\[^ \t\]*(\[^\n\]+)" $log dummy date
                            set date [clock scan $date]
                        }
                        regsub "^/jdk2/" $dir "" dir
                        regsub "/open$" $dir "" dir

                        set item $dir:$b
                        set seen($item) $date
                        set cur($item) $iscurrent
                        set len [string len $dir]
                        if {$maxlen < $len} {
                            set maxlen $len
                        }
                    }
                }
            } xx]} {
                puts $xx
            }
            cd $PWD
        }
    }
}

proc compare_by_timestamp {a b} {
    global seen
    return [expr $seen($a) - $seen($b)]
}


set dirfmt "%-${maxlen}s %s%s"

foreach item [lsort -command compare_by_timestamp [array names seen]] {
    set list [split $item :]
    set dir [lindex $list 0]
    set b   [lindex $list 1]
    if {$cur($item)} {
        set c " *"
    } else {
        set c "  "
    }

    puts "[clock format $seen($item)] [format $dirfmt $dir $c $b]"
}
