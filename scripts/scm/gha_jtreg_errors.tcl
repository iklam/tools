# gha_jtreg_errors.tcl --
#
# Quickly view the error status in a jtreg log file executed by GitHub Actions
#
# Example:
#
# wget -O log 'https://pipelines.actions.githubusercontent.com/serviceHosts/8c9d2c20-1b3a-4732-a7af-b7acbc30c5d2/_apis/pipelines/1/runs/764/signedlogcontent/590?urlExpires=2023-04-18T18%3A54%3A57.6949429Z&urlSigningMethod=HMACV1&urlSignature=QehuvJg5Go8H24T119qnm0dBbkxmAb7usNiLxotqLuA%3D'
# tclsh gha_jtreg_errors.tcl < log

set head {^20..-..-.....:..:...........}
set lasttest "??"
set message ""
while {![eof stdin]} {
    set line [gets stdin]
    if {[regexp "$head TEST: (.*)" $line dummy lasttest]} {

    } elseif {[regexp "$head TEST RESULT: (.*)" $line dummy result]} {
        if {![regexp {^Passed. } $result]} {
            puts "-----------------------------------------------------------"
            puts $lasttest
            puts "RESULT: $result"
            if {$argv == "-v"} {
                puts ""
                puts -nonewline $message
                puts "RESULT: $result"
            }
        }
    } else {
        regsub "$head " $line "" line
        append message $line\n
    }
}
