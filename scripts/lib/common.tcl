# Only one character arguments are supported. E.g., if you want to check
# existence of "-n" in the command-line, use
#   set arg_n [pop_arg n]
#   if {$arg_n} {
#       puts "You have specified -n"
#   }
proc pop_arg {c} {
    global argv
    set list {}
    set found 0
    foreach a $argv {
        #puts $a=$c
        if {"$a" == "-$c"} {
            set found 1
        } else {
            lappend list $a
        }
    }
    set argv $list
    return $found
}

