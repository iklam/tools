set host localhost

if {[catch {
    set sock_fd [socket localhost 9989]
    puts $sock_fd maxjobs
    flush $sock_fd
    set num [gets $sock_fd]
    puts $num
} err]} {
    puts stderr "distcc: Error $err"
    flush stderr
    puts 32
}

