# Usage
#
# tclsh strip_nonascii.tcl < in.txt > out.txt

set data [read stdin]
set pat {[^\u0020-\u007f\n\t]}
regsub -all $pat $data "?" data
regsub -all " +\n" $data "\n" data
puts $data
