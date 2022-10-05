set host localhost

if {[catch {
    set sock_fd [socket localhost 9989]
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

if {[info exists env(DISTCC_TRACE)]} {
    puts "distcc: host = $host"
}

if {$doit} {
    # distcc_exec.sh will first cd to the correct directory
    # (all the remote hosts see the same directory layout as the current host, thanks to NFS mount)
    set cmd "ssh $host /jdk3/tools/scripts/myide/distcc_exec.sh [pwd]"

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
