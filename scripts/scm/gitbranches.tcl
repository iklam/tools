# Look at all the branches of all the repos and sort them by time, so I know what I am working on

set locations {/jdk2/*/open /jdk3/*/open}

set maxlen 0
foreach pat $locations {
    set dirs [glob -nocomplain $pat]
    foreach dir $dirs {
        if {[file exists $dir/.git]} {
            set PWD [pwd]
            if {[catch {
                cd $dir
                foreach b [split [exec bash -c "git branch 2>&1"] \n] {
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
                        regsub "^/jdk3/" $dir "" dir
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
                puts [pwd]
                puts $xx
                exit 1
            }
            cd $PWD
        }
    }
}

proc compare_by_timestamp {a b} {
    global seen
    return [expr $seen($a) - $seen($b)]
}

proc get_title {b} {
    global table
    set cache ~/.gitbranches

    if {![array exists table]} {
        catch {
            set fd [open $cache r]
            while {![eof $fd]} {
                set br [gets $fd]
                set name [gets $fd]
                set table($br) $name
            }
            close $fd
        }
    }

    if {![info exists table($b)]} {
        set title "??"
        catch {
            set url https://github.com/openjdk/jdk/$b
            set fd [open "|wget -O - -q $url" r]
            while {![eof $fd]} {
                set line [gets $fd]
                if {[regexp {<title>([^<]+)</title>} $line dummy title]} {
                    regsub { ·.*} $title "" title
                    break;
                }
            }
            catch {close $fd}
        }
        set table($b) $title
        
        set fd [open $cache w+]
        foreach br [array names table] {
            puts $fd $br
            puts $fd $table($br)
        }
        close $fd
    }

    return $table($b)
}

set verbose 0
set activeonly 0

foreach arg $argv {
    if {"$arg" == "-v"} {
        set verbose 1
    }
    if {"$arg" == "-c"} {
        set activeonly 1
    }
}

set dirfmt "%-${maxlen}s %s%s%s"
set N {[0-9]}
set bugid_exp "($N$N$N$N$N$N$N)"
foreach item [lsort -command compare_by_timestamp [array names seen]] {
    set list [split $item :]
    set dir [lindex $list 0]
    set b   [lindex $list 1]
    if {$cur($item)} {
        set c " *"
    } else {
        set c "  "
        if {!$activeonly} {
            continue
        }
    }

    set pr_title ""
    if {[regexp {^pull/[0-9]+$} $b]} {
        set pr_title " [get_title $b]"
    } else {
        if {[regexp $bugid_exp $b dummy bugid] && $verbose} {
            set pr_title " https://bugs.openjdk.java.net/browse/JDK-$bugid"
        }
    }

    puts "[clock format $seen($item)] [format $dirfmt $dir $c $b $pr_title]"
}
