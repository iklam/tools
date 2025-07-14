# This is executed in a subprocess bu jtreg_report_lib.tcl
#
# The output has 3 lines:
#    $reason
#    $elapsed
#    $num_child

package require Tcl 8.4

proc make_link {html log} {
    foreach dummy [file split [file dirname $html]] {
        set log "../$log"
    }
    return $log
}

proc trim_cmdline {line} {
    set n 0
    set last_cp1 -1
    set last_cp2 -1
    foreach item [split $line " "] {
        set arr($n) $item
        if {[string comp "-cp" "$item"] == 0 || [string comp "-jar" "$item"] == 0} {
            set skip($last_cp1) 1
            set skip($last_cp2) 1
            set last_cp1 $n
            set last_cp2 [expr $n + 1]
        }
        incr n
    }

    set result ""
    set prefix " "
    for {set i 0} {$i < $n} {incr i} {
        if {![info exists skip($i)]} {
            append result $prefix
            append result $arr($i)
            set prefix " "
        }
    }

    return $result
}

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

    set jtr_data_dir [file root $jtr]

    set fd [open $jtr r+]
    set link $jtr
    regsub -all "#" $link %23 link
    set data "<body onload='location.href=\"#log1\"'><pre STYLE='white-space: pre-wrap;'>"
    append data {
        <script>
        function myKeyPress(e) {
            console.log(e.key)
            element = document.getElementById("llog" + e.key);
            if (element != null) {
                console.log(element);
                element.scrollIntoView();
            }
        }
        window.addEventListener("keydown", myKeyPress);
        </script>
    }
    set stdout_pat {(logging std... to) (.*[.]std...)}
    set output_pat {(output file:) ([^ ]+) [0-9]* bytes}
    set hserr_pat {(#) (.*log)}
    set num_logs 0
    set jtrdata ""

    set process_pat {^\[202.-[0-9].*for process [0-9]+$}
    while {![eof $fd]} {
        set line [gets $fd]
        append jtrdata $line\n

        if {[regexp {test result: Failed. (.*)} $line dummy err]} {
            set reason "execStatus=Failed $err<br>$reason"
        }

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
                set line "<b><font color=#802020>$line</font></b>"
            }
        }

        if {[string first "\[20" $line] == 0 && [regexp $process_pat $line]} {
            # this is pretty useless
            continue;
        } elseif {[string first "Command line: \[" $line] == 0 ||
                  [string first "\[COMMAND\]" $line] == 0} {
            incr num_logs
            set line "<div id=llog$num_logs><a name=log$num_logs><br><hr>\[$num_logs\]</a> [trim_cmdline $line]</div>"
        } elseif {[string first "logging std" $line] >= 0 && [regexp $stdout_pat $line dummy dummy filename]} {
            set line [fix_link $jtr_data_dir $stdout_pat $filename $line]
        } elseif {[string first "\[output file:" $line] >= 0 && [regexp $output_pat $line dummy dummy filename]} {
            set line [fix_link $jtr_data_dir $output_pat $filename $line]
        } elseif {[string first "hs_err_pid" $line] >= 0 && [regexp $hserr_pat $line dummy dummy filename]} {
            set line [fix_link $jtr_data_dir $hserr_pat $filename $line]

            incr num_logs
            set line "<div id=llog$num_logs><a name=log$num_logs></a>$line</div>"
            set iserr($num_logs) 1
        } elseif {[string first .log $line] > 0} {
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

    set r [print_hs_err_files $jtr_data_dir]
    if {"$r" != ""} {
        append reason $r
    }

    close $fd
    set fd [open $html w+]

    set header {
        <html>
        <link href="/favicon2.ico" rel="icon" type="image/x-icon" />
        <head>
        <style>
        /* The navigation bar */
        .navbar {
            overflow: hidden;
            background-color: rgba(50, 50, 50, 0.3);
            position: fixed; /* Set the navbar to fixed position */
            top: 0; /* Position the navbar at the top of the page */
            left: 120;
            width: 100%; /* Full width */
        }

        /* Links inside the navbar */
        .navbar a {
            float: left;
            display: block;
            color: #ff0000;
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
            margin-top: 50px; /* Add a top margin to avoid content overlay */
        }
        </style>
        </head>
        <body>
        <div class="navbar">
    }

    append header "<a href=[file tail $jtr]>orig</a>"
    set lnum 0
    set enum 0
    for {set i 1} {$i <= $num_logs} {incr i} {
        if {[info exists iserr($i)]} {
            incr enum
            append header "<font color=#ff0000><a href='#log${i}'>E$enum</a></font>"
        } else {
            incr lnum
            append header "<a href='#log${i}'>$lnum</a>"
        }
    }
    append header {
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
    puts $fd "set g_data($jtr,reason) [list $reason]"
    puts $fd "set g_data($jtr,elapsed) $elapsed"
    puts $fd "set g_data($jtr,num_child) $num_child"
    close $fd

    puts $reason
    puts $elapsed
    puts $num_child
}


proc fix_link {jtr_data_dir pat filename line} {
    global env g_data

    set filename [file tail $filename]
    set mts 0
    set mtd 0
    set s work/scratch/$filename
    set d $jtr_data_dir/$filename
    if {[file exists $s]} {
        set mts [file mtime $s]
    }
    if {[file exists $d]} {
        set mtd [file mtime $d]
    }
    if {$mts > 0 || $mtd > 0} {
        if {$mts >= $mtd} {
            set file $s
            set g_data(from_scratch) 1
        } else {
            set file $d
            set g_data(from_scratch) 0
        }
        regsub {^[.]/} $file "" file

        set size [file size $file]
        set link /$env(JTREG_DIR)/$file
        regsub -all \# $link %23 link
        set file "<a href=$link>$filename</a> [format {%7d bytes} $size]"
        regsub $pat $line "\\1 $file" line
    }
    return $line
}

proc print_hs_err_files {jtr_data_dir} {
    global env g_data

    if {[info exists g_data(from_scratch)] && $g_data(from_scratch) == "1"} {
        set dir work/scratch/
    } else {
        set dir $jtr_data_dir
    }

    set result ""
    set prefix ""
    foreach f [glob -nocomplain $dir/hs_err\*.log] {
        set fd [open $f]
        set data [read $fd]
        close $fd
        regsub {[-]* S U M M A R Y.*} $data "" data
        regsub -all "#\[ \n\r\]*" $data "" data
        regsub "A fatal error has been\[^\n\]*\n" $data "" data
        regsub "JRE version:\[^\n\]*\n" $data "" data
        regsub "Java VM:\[^\n\]*\n" $data "" data
        regsub "Problematic frame:\[^\n\]*\n" $data "" data
        regsub "Core dump will be written.*" $data "" data
        set data [string trim $data]
        regsub -all \n $data <br> data
        append result $prefix
        set prefix <br>
        append result $data
    }

    return $result
}

convert_html [lindex $argv 0]
