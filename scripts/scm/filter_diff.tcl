# Remove the noise from git diff files
#
# Usage:
#
# tclsh filter_diff.tcl < old.diff > old.txt
# tclsh filter_diff.tcl < new.diff > new.txt
#
# You can then use a graphical diff program to compare the two files. E.g.,
# tkdiff old.txt new.txt

while {![eof stdin]} {
    set line [gets stdin]
    regsub {^index [0-9a-f.]+ [0-9]+} $line {index - -} line
    regsub {^@@ [0-9,+-]+ [0-9,+-]+ @@} $line {@@ - - @@} line

    regsub {^[-][-][-] a/.*/([^/]+)$} $line {--- a/\1} line
    regsub {^[+][+][+] b/.*/([^/]+)$} $line {+++ b/\1} line
    regsub {^diff --git a/.*/([^/]+) b/.*/([^/]+)$} $line {diff --git a/\1 b/\1} line

    if {[lindex $argv 0] == "-s" && [string index $line 0] == " "} {
        # -s means strpping out out the surrounding lines
        continue
    }
    puts $line
}
