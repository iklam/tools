source [file dirname [info script]]/../process_lib.tcl

proc my_callback {handle results} {
    puts "handle = $handle"
    foreach line $results {
        puts "    $line"
    }
    exit
}

process_dispatch foo "find .. -type f" my_callback



vwait forever
