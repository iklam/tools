# Open fles in emacs in a bunch of different situations.

source [file dirname [info script]]/../lib/xraise.tcl
source [file dirname [info script]]/../lib/common.tcl

# -w means open in web (github)
if {[pop_arg w]} {
    set open_in_web 1
} else {
    set open_in_web 0
}

if {![info exists env(REPO_ROOT)]} {
    set env(REPO_ROOT) /jdk2/gil
}

foreach {a b} {
    o    open
    c    closed
    h    open/src/hotspot
    jb   open/src/java.base
    j    open/src/java.base
    t    open/test
    ocds open/test/hotspot/jtreg/runtime/cds
    ccds closed/test/hotspot/jtreg/runtime/cds
    ig   $env(IOIGIT)
} {
    lappend quickies $a
    set quick($a) [file join $env(REPO_ROOT) $b]
}

if {[llength $argv] == 0} {
    foreach a $quickies {
        puts [format "        %-5s %s" $a $quick($a)]
    }
    exit
}

proc openfile {file {lineno {}}} {
    global open_in_web
    if {$open_in_web} {
        regsub {^.*/open/} $file "" file
        set url https://github.com/openjdk/jdk/blob/master/$file
        puts $url
        set fd [open "|xclip -i" w+]
        puts -nonewline $fd $url
        close $fd
    } else {
        edit_in_emacs $file $lineno
    }
    exit
}

proc try_open_file_and_exit {file} {
    global find
    set lineno {}
    if {[regexp {(.*):([0-9]+)(:|)$} $file dummy file lineno]} {
        ## puts "$file (lineno =  $lineno)"
    }

    if {([regexp {^([^:]+):(.*)} $file dummy file text] && [puts --$file--; file exists $file]) ||
        [regexp {^([^: ]+/[^: /]+):(.*)} $file dummy file text]} {
        # This is typical output from grep, such as
        # ./closed/src/hotspot/share/jfr/jfr.cpp:jint Jfr::initialize_subsystems(TRAPS) {...}
        ##puts "cleaned up $file"

        if {$lineno == {} && $text != "" && [file exists $file]} {
            catch {
                set fd [open $file]
                set n 0
                while {![eof $fd]} {
                    incr n
                    set fline [gets $fd]
                    if {"$fline" == "$text"} {
                        set lineno $n
                        break
                    }
                }
            }
            catch {close $fd}
        }
    }

    puts $lineno=$file

    if {[file exists $file] || !$find} {
        if {$lineno != ""} {
            openfile $file +$lineno
        } else {
            openfile $file
        }            
        exit
    }
}

set find 1

if {[lindex $argv 0] == "-nofind"} {
    set argv [lrange $argv 1 end]
    set find 0
}

proc tosrc {file} {
    regsub {[.]o$} $file ".cpp" file
    regsub {[.]$}  $file ".cpp" file
    return $file
}

if {[llength $argv] == 1} {
    set file [lindex $argv 0]
    try_open_file_and_exit $file
    set file [tosrc $file]
    set repofile $env(REPO_ROOT)/open/$file
    if {![file exists $file] && [file exists $repofile]} {
        try_open_file_and_exit $repofile
    }
    try_open_file_and_exit $file
    try_open_file_and_exit $repofile

    set roots ""
    if {[regexp {[.]java} $file]} {
        if {[regexp -nocase test $file]} {
            lappend roots $env(REPO_ROOT)/open/test
        }
        lappend roots $env(REPO_ROOT)/open/src/java.base
        lappend roots $env(REPO_ROOT)/open/src
        lappend roots $env(REPO_ROOT)/open/test
    } elseif {[regexp {[.][ch]pp} $file]} {
        lappend roots $env(REPO_ROOT)/open/src/hotspot
        lappend roots $env(REPO_ROOT)/open/src
    } elseif {![regexp {[.]} $file]} {
        lappend roots $env(REPO_ROOT)/open/src
    }
    lappend roots $env(REPO_ROOT)/open
    lappend roots $env(REPO_ROOT)
    lappend roots .
} elseif {[llength $argv] == 2} {
    set root [lindex $argv 0]
    set file [lindex $argv 1]
    set file [tosrc $file]
    foreach a $quickies {
        if {$root == $a} {
            set roots $quick($a)
            break
        }
    }
} else {
    exit 0
}

if {![regexp {[*]} $file] && ![regexp {[.][a-z]+$} $file]  } {
    set file $file*
}

set pat {:([0-9]+)[*]$}
if {[regexp $pat $file dummy lineno]} {
    regsub $pat $file "" file
    set lineno +$lineno
} elseif {[regexp {^([^: ]+/[^: /]+):(.*)} $file dummy file text]} {
    # This is typical output from grep, such as
    # ./closed/src/hotspot/share/jfr/jfr.cpp:jint Jfr::initialize_subsystems(TRAPS) {...}
    openfile $file
} else {
    set lineno ""
}

foreach root $roots {
    set started [clock seconds]
    puts -nonewline "Searching under $root ..."
    flush stdout
    set cmd "| find $root -name .hg -prune -o -type f -a -name [list $file] -print | grep -v objectweb/asm"
    puts " [expr [clock seconds] - $started] secs"
    puts $cmd
    set list {}
    set fd [open $cmd]
    while {![eof $fd]} {
        set line [string trim [gets $fd]]
        puts $line
        if {[regexp {[~]$} $line] && ![regexp {~$} $file]} {
            continue
        }
        if {[regexp {^[.]#$} $line]} {
            continue
        }
        if {[regexp {[.]((class)|(o)|(lib)|(obj))$} $line]} {
            continue
        }
        if {[string eq $line ""]} {
            continue
        }
        lappend list $line
    }

    if {[llength $list] > 0} {
        if {[llength $list] == 1} {
            set target [lindex $list 0] 
            puts "qe $target"
            openfile $target $lineno
        } else {
            foreach n [lsort $list] {
                puts $n
            }
        }
        exit
    }
}
