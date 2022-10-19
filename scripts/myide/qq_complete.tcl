# Auto-complete support for the "qq" bash command

set pattern [lindex $argv 0]

set dirs [list [pwd]]

if {[regexp {^[a-z]} $pattern]} {
    set pwd [pwd]
    if {[info exists env(REPO_ROOT)]} {
        if {[file exists $env(REPO_ROOT)/open/src/hotspot]} {
            set target $env(REPO_ROOT)/open/src/hotspot
        } else {
            set target $env(REPO_ROOT)/hotspot
        }
    } else {
        if {[regexp {^/jdk2/emmett/jdk8/hotspot} $pwd]} {
            set target /jdk2/emmett/jdk8/hotspot
        } elseif {[regexp {^/jdk2/emmett/jdk17/open/src/hotspot} $pwd]} {
            set target /jdk2/emmett/jdk17/open/src/hotspot
        }
    }

    if {![string match ${target}* $pwd]} {
        set dirs [list $target]
    }
} elseif {[regexp {^[A-Z]} $pattern]} {
    set pwd [pwd]
    set target1 $env(REPO_ROOT)/open/src/java.base

    if {![string match ${target1}* $pwd]} {
        set dirs [list $target1 $env(REPO_ROOT)/open/test/lib]
    }
}

foreach dir $dirs {
    if {[catch {cd $dir}]} {
        continue
    }
    set lines {}
    catch {
        set lines [exec find . -name "${pattern}*"]
    }
    set found ""
    set prefix ""
    foreach line $lines {
        if {![regexp {((pp)|(java))$} $line]} {
            continue
        }
        if {[regsub {^.*/} $line "" line]} {
            if {![info exists seen($line)]} {
                set seen($line) 1
                append found $prefix$line
                set prefix "\n"
            }
        }
    }
    puts $found
}

