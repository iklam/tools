# This is executed in a subprocess bu jtreg_report_lib.tcl
#
# The output has 3 lines:
#    $reason
#    $elapsed
#    $num_child

package require Tcl 8.4

proc convert_html {jtr} {
    global logfiles env
    cd ~/tmp/$env(JTREG_DIR)

    regexp {[.]/work/(.*)[.]jtr} $jtr dummy testname
    set html $jtr.html
    set stat $jtr.stat

    set want_except 0
    set reason ""

    if 0 {
        # remove unnecessary clutter

        regsub "execStatus=Failed. " $reason "" reason
        if {[regexp "Execution failed: `main' threw exception: (.*)" $reason dummy except]} {
            set reason "Thrown: $except"
            set want_except 1
        }
    }

    set fd [open $jtr r+]
    set link $jtr
    regsub -all "#" $link %23 link
    set data "<pre STYLE='white-space: pre-wrap;'>"
    set pat {(logging std... to) (.*[.]std...)}
    set num_logs 0
    set jtrdata ""
    while {![eof $fd]} {
        set line [gets $fd]
        append jtrdata $line\n
        if {[regexp "\[\#\\\\&<>\]" $line]} {
            if {[regexp "\#  (assert\[\(\].*)" $line dummy assert]} {
                append reason "<br>&nbsp;&nbsp;<font color=#f04040>$assert</font>"
            }
            regsub  {\\\\$} $line "\\" line
            regsub -all {\\=} $line "=" line
            regsub -all {\\:} $line ":" line
            regsub -all "&" $line "\\&amp;" line
            regsub -all "<" $line "\\&lt;" line
            regsub -all ">" $line "\\&gt;" line
            if {[string index $line 0] == "#"} {
                set line "<b><font color=#602020>$line</font></b>"
            }
        }

        if {[string first "logging std" $line] >= 0 && [regexp $pat $line dummy dummy filename]} {
            set ttt $testname
            regsub .*/ $ttt "" ttt
            set fff $filename
            regsub .*/ $fff "" fff
            foreach index [list $ttt,$fff scratch,$fff] {
                #puts ====$index
                if {0 && [tsv::exists logfiles $index]} {
                    #puts huh
                    incr num_logs
                    set anchor "<a name=log$num_logs></a>"
                    set item [tsv::get logfiles $index]
                    set file [lindex $item 0]
                    set size [lindex $item 1]
                    set link [make_link $html $file]
                    regsub -all "#" $link %23 link
                    set file "$anchor<a href=$link>$filename</a> [format {%7d bytes} $size]"
                    regsub $pat $line "\\1 $file" line
                    break
                }
            }
        } else {
            set xpat "^# (/jdk.*/tmp/$env(JTREG_DIR)/work/scratch/.*.log)"
            if {[regexp $xpat $line dummy path]} {
                regsub "^/jdk.*/tmp/$env(JTREG_DIR)/" $path "" file
                set link [make_link $html $file]
                set line "# <a href=$link>$path</a>"
            }
        }

        if {$want_except == 1} {
            if {[string comp $except $line] == 0} {
                set want_except 2
            }
        } elseif {$want_except == 2} {
            if {[regexp "^\t+at " $line]} {
                if {![regexp jdk.test.lib.Asserts $line]} {
                    append reason "<br>&nbsp;&nbsp;<font color=#f04040>[string trim $line]</a>"
                    set want_except 0
                }
            } else {
                set want_except 0
            }
        }

        if {[regexp "Caused by: java.lang.RuntimeException: (test.* failed: expected.*)" $line dummy failed_test]} {
            append reason "<br>$failed_test"
        }
        append data \n$line
        incr n
    }
    close $fd
    set fd [open $html w+]

    set header {
        <html>
        <head>
        <style>
        /* The navigation bar */
        .navbar {
            overflow: hidden;
            background-color: #333;
            position: fixed; /* Set the navbar to fixed position */
            top: 0; /* Position the navbar at the top of the page */
            width: 100%; /* Full width */
        }

        /* Links inside the navbar */
        .navbar a {
            float: left;
            display: block;
            color: #f2f2f2;
            text-align: center;
            padding: 14px 16px;
            text-decoration: none;
        }

        /* Change background on mouse-over */
        .navbar a:hover {
            background: #ddd;
            color: black;
        }

        /* Main content */
        .main {
            margin-top: 60px; /* Add a top margin to avoid content overlay */
        }

        </style>
        </head>
        <body>
        <div class="navbar">
    }

    append header "<a href=[file tail $link]>orig</a>"
    append header {
        <a href="#log1">First</a>
        <a href="#log2">Second</a>
        </div>
        <div class="main">
    }
    set data "$header$data</div>"
    puts $fd $data
    close $fd

    if {[regexp "# Problematic frame:.#(\[^#\]+)" $jtrdata dummy frame]} {
        append reason "<br>$frame"
    }
    set elapsed "&nbsp;"
    regexp {elapsed=([0-9]+)} $data dummy elapsed
    set num_child [regsub -all {\[ELAPSED: } $data "" foo]

    set fd [open $stat w+]
    puts $fd "set g_data($jtr,reason) $elapsed"
    puts $fd "set g_data($jtr,elapsed) $elapsed"
    puts $fd "set g_data($jtr,num_child) $num_child"
    close $fd

    puts $reason
    puts $elapsed
    puts $num_child
}

convert_html [lindex $argv 0]
