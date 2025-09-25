set file ~/tmp/$env(JTREG_DIR)/failed.txt 

if {![file exists $file]} {
    exit
}

set fd [open $file]
set pwd [pwd]
set pwdlen [expr [string len $pwd] + 1]

while {![eof $fd]} {
    set line [string trim [gets $fd]]
    if {"$line" == ""} {
        continue
    }
    set pat {_([^.]*)[.]java}
    set id ""

    for {set i 0} {$i < 2} {incr i} {
        if {$i == 1} {
            if {[regexp $pat $line dummy id]} {
                regsub $pat $line ".java" line
            }
        }

        set f $line
        set found 0

        foreach dir {open/test/hotspot/jtreg open/test/jdk closed/test/hotspot/jtreg} {
            set a $env(REPO_ROOT)/$dir/$f
            if {[file exists $a]} {
                set f $a
                set found 1
                break
            }
        }
        if {$found == 1} {
            break
        }
    }
    
    if {[string first $pwd $f] == 0} {
        #set f [string range $f $pwdlen end]
    }
    if {"$id" == ""} {
        lappend list $f
    } else {
        lappend list "$f#$id"
    }
}

if {[info exists list]} {
    foreach i [lsort $list] {
        puts $i
    }
}

