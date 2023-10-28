# Looks at -XX:+TraceBytecodes and see how many bytecodes are executed in <clinit> methods.

set nBytecodes 0

proc push_clinit {thread clsName methodName} {
    global startedInit clinitClassStack clinitMethodStack nBytecodes curClinit

    if {![info exists startedInit($clsName)]} {
        set startedInit($clsName) $nBytecodes
        lappend clinitClassStack($thread) $clsName
        lappend clinitMethodStack($thread) $methodName

        set curClinit($thread) $methodName
        puts -nonewline "\[$thread\] "
        for {set i 1} {$i < [llength $clinitClassStack($thread)]} {incr i} {
            puts -nonewline " "
        }
        puts $clsName
    }
}

proc pop_clinit {} {
    global startedInit clinitClassStack clinitMethodStack nBytecodes curClinit curThread grandTotal


    puts -nonewline "\[$curThread\] "
    for {set i 1} {$i < [llength $clinitClassStack($curThread)]} {incr i} {
        puts -nonewline " "
    }
    set clsName [lindex $clinitClassStack($curThread) end]
    set initTotal [expr $nBytecodes - $startedInit($clsName)]

    puts "$clsName finished $initTotal bytecodes"

    set size [llength $clinitClassStack($curThread)]
    if {$size <= 1} {
        set clinitClassStack($curThread) {}
        set clinitMethodStack($curThread) {}
        incr grandTotal($curThread) $initTotal
    } else {
        set clinitClassStack($curThread)  [lrange $clinitClassStack($curThread)  0 [expr $size - 2]]
        set clinitMethodStack($curThread) [lrange $clinitMethodStack($curThread) 0 [expr $size - 2]]
        set next " ([llength clinitClassStack($curThread)])"
    }
    set curClinit($curThread) [lindex $clinitMethodStack($curThread) end]
    #parray clinitClassStack
}

proc is_in_clinit_method {} {
    global curMethod curClinit curThread 
    if {[info exists curClinit($curThread)] &&
        [info exists curMethod($curThread)] &&
        $curMethod($curThread) == $curClinit($curThread)} {
        return 1
    } else {
        return 0
    }
}


while {![eof stdin]} {
    set line [gets stdin]
    if {[string trim $line] == ""} {
        continue
    }
    if {[regexp {^[0-9]+ bytecodes executed} $line]} {
        continue
    }
    if {[regexp {^.([0-9]+). ([^ ].*)$} $line dummy thread methodName]} {
        set curMethod($thread) $methodName
        set curThread $thread
        if {[regexp {^static void ([a-zA-Z0-9.$]+)[.]<clinit>[(][)]} $methodName dummy clsName]} {
            regsub -all {[.]} $clsName / clsName
            push_clinit $thread $clsName $methodName
            #puts $thread-$clsName
        }
    } else {
        incr nBytecodes
        if {[regexp {^.([0-9]+). [ ]+[0-9]+[ ]+[0-9+)[ ]+return$} $line]} {
            if {[is_in_clinit_method]} {
                #puts $line
                pop_clinit
            }
            #puts $line
        }
    }
}

puts "Thread ID : bytecodes in clinit : % of total ($nBytecodes)"
foreach thread [lsort [array names curMethod]] {
    if {![info exists grandTotal($thread)]} {
        set grandTotal($thread) 0
    }

    puts [format {%-9s : %19d | %6.2f%% } $thread $grandTotal($thread) [expr $grandTotal($thread) / $nBytecodes.0 * 100]]
}
