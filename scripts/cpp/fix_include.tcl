
while {![eof stdin]} {
    set line [gets stdin]
    foreach {header pattern} {
        memory/resourceArea.hpp                  {ResourceMark.* incomplete type}
        interpreter/abstractInterpreter.hpp      {AbstractInterpreter. has not been declared}
    } {
        if {[regexp $pattern $line]} {
            if {[regexp {^(/.*pp):[0-9]} $line dummy file]} {
                if {![info exists fixed($file,$header)]} {
                    set fixed($file,$header) 1
                    puts "$file -> $header"

                    set fd [open $file]
                    set data [read $fd]
                    close $fd

                    if {![regexp "\#include .$header" $data]} {
                        regsub "\#include" $data "#include \"$header\"\n#include" data
                        set fd [open $file w+]
                        puts -nonewline $fd $data
                        close $fd
                        puts [exec java /jdk3/win/open/test/hotspot/jtreg/sources/SortIncludes.java --update $file]
                    }
                    #exit
                }
            }
        }
    }
}
