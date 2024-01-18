# This is unfinished utility for me to run jvm tests in the console ....
#
# function doit () {
#     jjrun $* -- -cp bar -Xlog:cds -XX:+UseNewCode com.sun.tools.javac.Main ~/tmp/HelloWorld.java
# }
#
# doit -gdb -XX:+TraceBytecodes -- -Xlog:cds=debug
#
# We parse the following parts:
#
# user_prefix = -gdb -XX:+TraceBytecodes 
# user_suffix = -Xlog:cds=debug
# orig_args   = -cp bar -Xlog:cds -XX:+UseNewCode
# orig_app    = com.sun.tools.javac.Main ~/tmp/HelloWorld.java

set user_prefix {}
set user_suffix {}
set orig_args {}
set orig_app {}

set stage user_prefix

proc do_append {} {
    global stage i argv len
    global $stage

    if {$i < $len} {
        set w [lindex $argv $i]
        if {[regexp {(.*)=([^=]* [^=]*)} $w dummy a b]} {
            # E.g., -foo='a b c'
            set w "$a='$b'"
        } elseif {[regexp " " $w]} {
            # there is space, escape it
            set w "\'$w\'"
        }

        if {[set $stage] == {}} {
            set $stage $w
        } else {
            append $stage " $w"
        }
    }
}

set len [llength $argv]
for {set i 0} {$i < $len} {incr i} {
    set w [lindex $argv $i]

    if {"$w" == "--"} {
        set stage user_suffix
        continue
    }
    if {"$w" == "---"} {
        set stage orig_args
        continue
    }

    if {$w == "-cp" || "$w" == "-classpath" || "$w" == "--add-exports" || "$w" == "--add-modules"} {
        do_append
        incr i
        do_append
    } else {
        if {[string index $w 0] != "-"} {
            set stage orig_app
        }
        do_append
    }
}

set prefix ""
foreach n [list $user_prefix $orig_args $user_suffix $orig_app] {
    if {$n != ""} {
        puts -nonewline $prefix$n
        set prefix " "
    }
}
puts ""

