set env(IOI_ORIG_CXX)          /home/iklam/devkit/latest/bin/g++
set env(IOI_ORIG_LDCXX)        /home/iklam/devkit/latest/bin/g++
set env(IOI_ORIG_BUILD_CXX)    /home/iklam/devkit/latest/bin/g++
set env(IOI_ORIG_BUILD_LDCXX)  /home/iklam/devkit/latest/bin/g++

proc read_compile_commands {} {
    global db

    set fd [open compile_commands.json]
    while {![eof $fd]} {
        set line [gets $fd]
        if {[regexp {\"file\": \"([^\"]+)\".*command\": \"(.*)\" \}} $line dummy file command]} {
            set db($file) $command
        }
    }
    close $fd
}

proc try_fix {file lineno header} {
    global fix_count ignore

    if {[info exists ignore($file,$header)]} {
        puts "FAILED (ignored)"
        return
    }

    set tmpfile $file.tmp.cpp
    set in [open $file]
    set out [open $tmpfile w+]
    set i 0
    set found 0
    set fixed 0
    while {![eof $in]} {
        incr i
        set line [gets $in]
        if {$i == $lineno} {
            # Don't touch things like "#include OS_HEADER_INLINE(os)"
            if {[string index $line 0] == "#" && ![regexp {[A-Za-z0-9_][\(]} $line]} {
                puts $out "//NONEED $line"
                set found 1
            } else {
                set fixed 1
                break
            }
        } else {
            if {![eof $in] || "$line" != ""} {
                puts $out "$line"
            }
        }
    }

    close $in
    close $out

    if {$fixed} {
        puts " .."
        file delete -force $tmpfile
        return
    }
    if {!$found} {
        file delete -force $tmpfile
        puts "not found"
        return
    }

    if {[catch {
        global db
        set cmd $db($file)
        regsub $file $cmd $file.tmp.cpp cmd
        regsub -all {[\\]\"} $cmd "\"" cmd
        regsub {[-]frandom-seed.*} $cmd "" cmd
        set data [exec bash -c "$cmd"]
        #puts ==$data
    } err]} {
        file delete -force $tmpfile
        puts "FAILED"
        set ignore($file,$header) 1
        write_config_file
    } else {
        file rename -force $tmpfile $file
        exec touch $file
        incr fix_count
        puts "GOOD";
        if {$fix_count > 10} {
            exit
        }
    }
}

proc read_config_file {} {
    catch {
        source /tmp/remove_unneeded_include.cfg
    }
}

proc write_config_file {} {
    global ignore
    set fd [open /tmp/remove_unneeded_include.cfg.new w+]
    puts $fd "global ignore"
    foreach name [lsort [array names ignore]] {
        puts $fd "set ignore($name) 1"
    }
    close $fd
    file rename -force /tmp/remove_unneeded_include.cfg.new /tmp/remove_unneeded_include.cfg.new
}

read_compile_commands
read_config_file
while {![eof stdin]} {
    set line [gets stdin]
    if {[regexp {(^/[^ :]+):([0-9]+):([0-9]+): .* header ([^ ]+) is not used directly} $line dummy file lineno charno header]} {
        puts -nonewline "Fixing $file:$lineno $header: "
        try_fix $file $lineno $header
    }
}
