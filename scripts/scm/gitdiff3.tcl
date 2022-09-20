# gitdiff3.tcl
#
# Usage:
#
# tclsh gitdiff3.tcl file1 <rev1> file2 <rev2>
#
# <rev1> and <rev2> are optional
#
# The two files should be in two different repos that have related history
#
# We find a common ancestor to both file1 and file2.

set f1 [lindex $argv 0]
if {[file exists [lindex $argv 1]]} {
    set r1 HEAD
    set f2 [lindex $argv 1]
    set r2 [lindex $argv 2]
} else {
    set r1 [lindex $argv 1]
    set f2 [lindex $argv 2]
    set r2 [lindex $argv 3]
}

if {"$r2" == ""} {
    set r2 HEAD
}
if {"$r1" == ""} {
    set r1 HEAD
}

proc get_logs {f r} {
    set pwd [pwd]
    cd [file dirname $f]
    set list [split [exec git log $r [file tail $f] | grep {^commit} | sed -e {s/commit //g} ] \n]
    cd $pwd
    return $list
}

proc get_file {f r dst} {
    #puts $f=$r=[pwd]
    set pwd [pwd]
    cd [file dirname $f]
    #puts [pwd]
    exec git show $r:./[file tail $f] > $pwd/$dst
    cd $pwd
    puts "Written to $dst"
}

proc log_msg {f r} {
    #puts $f=$r=[pwd]
    set pwd [pwd]
    cd [file dirname $f]
    #puts [pwd]
    exec git log -1 $r ./[file tail $f] >@ stdout
    cd $pwd
}

puts "$f1 @ $r1"
puts "$f2 @ $r2"

set log1 [get_logs $f1 $r1]
set log2 [get_logs $f2 $r2]

foreach commit $log1 {
    set found1($commit) 1
}

set r1 [lindex $log1 0]
set r2 [lindex $log2 0]

foreach commit $log2 {
    if {[info exists found1($commit)]} {
        puts "  1 = $r1"
        log_msg $f1 $r1

        puts "found common commit - $commit"
        log_msg $f1 $commit

        puts "  2 = $r2"
        log_msg $f2 $r2


        # https://stackoverflow.com/questions/4018476/what-are-a-b-and-c-in-kdiff-merge
        # A refers to the version your merge target is based on. If you Merge from branch to trunk, 'A' will be the previous trunk version.
        # B is what you currently have in your local trunk folder, including local changes.
        # C is the Version you wanna merge on top of B.

        # Merge the 
        #

        # A
        get_file $f1 $commit base.cpp

        # B
        get_file $f2 $r2     work.cpp

        # C
        get_file $f1 $r1     target.cpp

        break;
    }  
}

# oops not done yet ....
