# Remove the noise from git diff files. This is useful for comparing a backport vs the original changeset.
#
# Usage:
#
# For example, looking at https://bugs.openjdk.org/browse/JDK-8245543:
#    "old" is the original changeset,
#    "new" is the backport to openjdk/jdk11u
#
# wget -O old.diff https://github.com/openjdk/jdk/commit/2bbf8a2a.diff
# wget -O new.diff https://github.com/openjdk/jdk11u-dev/commit/31cbb822fc9d7f2934ad473c4cb0c62f8f23e9c0.diff
#
#     If you just look at the diff files, there are a lot of noise like line-number differences and
#     git hashcodes. Also, file paths may be different.
#
# tclsh filter_diff.tcl < old.diff > old.txt
# tclsh filter_diff.tcl < new.diff > new.txt
#
#     You can then use a graphical diff program to compare the two files. E.g.,
#
# meld old.txt new.txt

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
