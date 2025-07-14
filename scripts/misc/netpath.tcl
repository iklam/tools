# Usage
# netpath localpath [host]
#
# If host is not specified, localpath is assumed to be a file on the local machine.
#
# If host is specified, localpath is assumed to be a local file on this host

proc out {path} {
    puts $path
    exit
}

set file [lindex $argv 0]
set host [lindex $argv 1]

if {"$host" == ""} {
    set host [info hostname]
}

set file [file join [pwd] $file]
if {[file isdir $file]} {
    set file [exec tcsh -c "cd $file; pwd"]
} else {
    set file [exec tcsh -c "cd [file dirname $file]; pwd"]/[file tail $file]
}

if {"$host" == "ioilinux"} {
    if {[regexp {^/home/iklam(/jdk/.*)} $file dummy tail]} {
        out /net/ioilinux$tail
    } elseif {[regexp {^(/jdk/.*)} $file dummy tail]} {
        out /net/ioilinux$tail
    }
}

# Don't know ...
puts $file
