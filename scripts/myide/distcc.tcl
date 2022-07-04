set host localhost

if {[catch {
    set sock_fd [socket localhost 9989]
    puts $sock_fd gethost
    flush $sock_fd
    set host [gets $sock_fd]
} err]} {
    if {[info exists env(DISTCC_TRACE)]} {
        puts "distcc: Error $err"
    }
}


if {$host == "localhost"} {
    set doit 0
} else {
    set doit 1
}

if {$doit} {
    set cmd "ssh $host"

    foreach a $argv {
        regsub -all \" $a \\\\\" a
        regsub -all " " $a "" a
        regsub -all \[(\] $a \\\\\( a
        regsub -all \[)\] $a \\\\\) a
        lappend cmd $a
    }
}

if {[info exists env(DISTCC_TRACE)]} {
    puts "distcc: doit = $doit"
}

if {[catch {
    if {$doit} {
        if {[catch {
            if {[info exists env(DISTCC_TRACE)]} {
                puts "distcc = $cmd"
            }
            eval exec $cmd >@ stdout 2>@ stderr
        } err]} {
            puts $err
            puts "distcc: redo locally"
            set doit 0
        }
    }
    if {$doit == 0} {
        eval exec $argv >@ stdout 2>@ stderr
    }
} err]} {
    puts $err
    exit 1
}
