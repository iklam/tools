# rebuild.tcl
#
#    - Build one or more hotspot .o files (using a saved .o.cmdline file, or the saved
#      command-lines from the last 'make' command
#     

if {[file exists hotspot/variant-server/] || [file exists hotspot/variant-minimal/]} {
    set env(MYJDK) [pwd]/images/jdk
} else {
    if {![info exists env(MYJDK)]} {
        puts "please select build type first. E.g., use_d"
        exit 1
    }

    cd $env(MYJDK)/../..
}

proc read_cmdline {cmdline file replace} {
    set fd [open $cmdline]
    set data [string trim [read $fd]]
    close $fd

    if {[regexp /jdk11 $data]} {
        regsub {.*/jdkbuildhack.sh CXX} $data /home/iklam/devkit/for-jdk11/bin/g++ data
    } else {
        regsub {.*/jdkbuildhack.sh CXX} $data /home/iklam/devkit/latest/bin/g++ data
    }
    regsub " -c " $data " -c -save-temps " data
    regsub " -pipe " $data " " data

    if {"$replace" != ""} {
        regsub {objs/[^ ]+.d.tmp } $data "objs/$replace.d.tmp " data
        regsub {objs/[^ ]+.o }     $data "objs/$replace.o " data
        regsub {frandom-seed="[^ ]+.cpp"} $data "frandom-seed=\"$replace.cpp\"" data

        set srcpat { (/[^ ]+/hotspot)/[^ ]+.cpp }
        if {[regexp $srcpat $data dummy root]} {
            set src ""
            catch {
                set src [string trim [exec find $root -name $replace.cpp -a -type f]]
            }
            if {"src" == ""} {
                puts "Cannot find source file $replace.cpp under $root"
                exit 1
            } elseif {[llength $src] != 1} {
                puts "huh? found more than one file:\n$src"
                exit 1
            }
            puts $src
        }
        regsub $srcpat $data " $src " data
    }

    puts "Rebuilding $file.o ..."
    puts "\t$data"

    append data " 2>&1 | tee /tmp/lastmake; exit \${PIPESTATUS\[0\]}"

    set fd [open /tmp/ioireb.sh w+]
    puts $fd "$data"
    close $fd

    if {![info exists dryrun]} {
        set start [clock milliseconds]
        if {[catch {
            exec bash /tmp/ioireb.sh >@ stdout 2>@ stderr
            puts "[expr [clock milliseconds] - $start] ms"
        }]} {
            puts "[expr [clock milliseconds] - $start] ms"
            puts "Error $file.o"
            exit 1
        }
    }
}

proc find_any_cmdline {} {
    foreach file [lsort [glob -nocomplain hotspot/variant-*/libjvm/objs/*.o.cmdline]] {
        set fd [open $file]
        set data [read $fd]
        close $fd
        if {[regexp {src/hotspot/share/[^ ]+.cpp } $data]} {
            return $file
        }
    }
    return ""
}

proc rebuild {file} {
    regsub .*/ $file "" file
    regsub {[.].*} $file "" file

    set cmdline hotspot/variant-server/libjvm/objs/$file.o.cmdline
    if {[file exists $cmdline]} {
        set args [read_cmdline $cmdline $file ""]
    } else {
        set cmdline [find_any_cmdline]
        if {$cmdline != ""} {
            set args [read_cmdline $cmdline $file $file]
        } else {
            puts "Cannot find cmdline for $file.cpp"
            return
        }
    }
    #exec cat $cmdline >@ stdout
}

foreach file $argv {
    rebuild $file
}
