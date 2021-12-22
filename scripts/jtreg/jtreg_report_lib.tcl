package require Tcl 8.4

set jtreg_scriptroot [file dirname [info script]]
source [file dirname $jtreg_scriptroot]/lib/process_lib.tcl

if {![info exists start]} {
    set start 0
}

# Order of writing:
# jtr -> jtr.html -> jtr.stat
# So if you see [mtime jtr.stat] >= [mtime jtr], there's no need to update the jtr file
#
# g_reports() -> all available reports
# g_updates() -> all reports that need to be regenerated
proc build_worklists {} {
    global g_reports g_updates env
    file mkdir ~/tmp/$env(JTREG_DIR)/report/html
    set pwd [pwd]
    cd ~/tmp/$env(JTREG_DIR)
    set me_started [clock milliseconds]

    set fd [open "|find . -name classes -prune -o -name *.jtr -print | sort"]
    while {![eof $fd]} {
        set f [string trim [gets $fd]]
        if {"$f" == ""} {
            continue
        }
        set mtfile [file mtime $f]
        set mthtml 0
        set mtstat 0
        if {[file exists $f.html]} {
            set mthtml [file mtime $f.html]
        }
        if {[file exists $f.stat]} {
            set mtstat [file mtime $f.stat]
        }
        set g_reports($f) $mtfile
        if {$mthtml < $mtfile || $mtstat < $mtfile} {
            set g_updates($f) 1
        } else {
            uplevel #0 source $f.stat
        }
    }

    if {[info exists env(TIMING)]} {
        puts "build_worklists = [expr [clock milliseconds] - $me_started] ms"
    }
}

proc do_work {} {
    global env g_reports g_updates jtreg_scriptroot g_data

    set me_started [clock milliseconds]

    foreach f [array names g_updates] {
        process_dispatch $f "tclsh $jtreg_scriptroot/jtreg_report_convert_html.tcl $f"
    }

    while 1 {
        set status [process_join]
        if {$status == {}} {
            break
        }
        set jtr [lindex $status 0]
        set results [lindex $status 1]
        set g_data($jtr,reason)    [lindex $results 0]
        set g_data($jtr,elapsed)   [lindex $results 1]
        set g_data($jtr,num_child) [lindex $results 2]
        #puts ---->$status
    }

    if {[info exists env(TIMING)]} {
        puts "do_work = [expr [clock milliseconds] - $me_started] ms"
    }
}

proc write_report_header {fd outfile} {
    global ffd

    catch {unset ffd}

    puts $fd {
        <head>
        <style>
        table {
            border-collapse: collapse;
        }
        table, td, th {
            border: 1px solid black;
        }
        </style>
        </head>

        <script>
        function sortTable(column) {
          var table, rows, switching, i, x, y, shouldSwitch;
          table = document.getElementById("myTable");
          switching = true;
          /*Make a loop that will continue until
          no switching has been done:*/
          while (switching) {
            //start by saying: no switching is done:
            switching = false;
            rows = table.rows;
            /*Loop through all table rows (except the
            first, which contains table headers):*/
            for (i = 0; i < (rows.length - 1); i++) {
              //start by saying there should be no switching:
              shouldSwitch = false;
              /*Get the two elements you want to compare,
              one from current row and one from the next:*/
              x = rows[i].getElementsByTagName("TD")[column];
              y = rows[i + 1].getElementsByTagName("TD")[column];
              x = Number(x.innerHTML.toLowerCase());
              y = Number(y.innerHTML.toLowerCase());
              //check if the two rows should switch place:
              if (x < y) {
                //if so, mark as a switch and break the loop:
                shouldSwitch = true;
                break;
              }
            }
            if (shouldSwitch) {
              /*If a switch has been marked, make the switch
              and mark that a switch has been done:*/
              rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
              switching = true;
            }
          }
        }
        </script>
    }

    if {$outfile == "failed.html"} {
        puts $fd "<h1>All failures | <a href=failed_latest.html> Latest failures</a> | <a href=index.html>All Results</a></h1>"
        set ffd [open failed.txt w+]
    } elseif {$outfile == "failed_latest.html"} {
        puts $fd "<h1><a href=failed.html>All failures</a> |  Latest failures | <a href=index.html>All Results</a></h1>"
    } elseif {$outfile == "index.html"} {
        puts $fd "<h1><a href=failed.html>All failures</a> | <a href=failed_latest.html> Latest failures</a> | All Results </h1>"
    }

    puts $fd {<p><button onclick="sortTable(3)">Sort by elapsed time</button>}
    puts $fd {<button onclick="sortTable(4)">Sort by num child processes</button>}

    puts $fd "<p><table id='myTable' cellpadding=2>"
}

proc update_report {outfile start_ms execStatus} {
    global start env g_reports ffd g_data
    file mkdir ~/tmp/$env(JTREG_DIR)/report/html
    cd ~/tmp/$env(JTREG_DIR)
    set me_started [clock milliseconds]
    set fd [open report/html/$outfile w+]

    write_report_header $fd outfile

    foreach jtr [lsort -dictionary [array names g_reports]] {
        set html $jtr.html
        regexp {[.]/work/(.*)[.]jtr} $jtr dummy test
        set reason    $g_data($jtr,reason)
        set elapsed   $g_data($jtr,elapsed)
        set num_child $g_data($jtr,num_child)

        if {[regexp execStatus=Failed $reason]} {
            set status "<td bgcolor=#ffa0a0>FAILED</td>"
        } elseif {[regexp execStatus=Error $reason]} {
            set status "<td bgcolor=#ffffa0>Error</td>"
        } else {
            set status "<td>&nbsp;</td>"
        }

        if {[string first "execStatus=Passed" $reason] >= 0 && [string first "SkippedException" $reason] < 0 } {
            set color "bgcolor=#d0f0d0"
        } else {
            set color ""
        }

        incr n
        puts $fd "<tr><td $color align=right>$n</td>"
        puts $fd "$status"
        puts $fd "<td $color valign=top><a href=../../${html}#log1>$test</a></td>"
        puts $fd "<td $color valign=top align=right>$elapsed</td>"
        puts $fd "<td $color valign=top align=right>$num_child</td>"
        puts $fd "<td $color valign=top>$reason</td></tr>"

        if {[info exists ffd]} {
            # hack!!
            set t $test
            regsub {_id[0-9]+$} $t "" t
            puts $ffd $t.java
        }
    }

    puts $fd "</table>"
    set s [expr [clock milliseconds] - $me_started]
    puts $fd "<br><br>Last Updated [clock format [clock seconds]] (Generated in $s ms)"
    close $fd
    catch {close $ffd}
    if {[info exists env(TIMING)]} {
        puts "generated $outfile $s ms"
    }
}

proc findlogfiles {} {
    set start [clock milliseconds]
    global has_found env
    if {[info exists has_found]} {
        return;
    }
    set has_found 1

    set fd [open "|find . -name *.stdout -print -o -name *.stderr -print "]
    while {![eof $fd]} {
        set file [gets $fd]
        #puts $file
        if {[regexp {([^/]+)/([^/]+)$} $file dummy testname filename]} {
            set key $testname,$filename
            if {[info exists seen($key)]} {
                set old $seen($key)
                set new $file

                if {[file mtime $new] > [file mtime $old]} {
                    #puts ..$old\n->$new
                    set seen($key) $file
                }
            } else {
                set seen($key) $file
            }
        }
    }

    foreach key [array names seen] {
        set file $seen($key)
        set size 0
        catch {
            # some files may be moved by jtreg while we are trying to read its size.
            set size [file size $file]
        }
        tsv::set logfiles $key [list $file $size]
    }

    if {[info exists env(TIMING)]} {
        puts "findlogfiles elapsed = [expr [clock milliseconds] - $start]"
    }
}

proc update_reports {start_ms} {
    global has_found env
    set start [clock milliseconds]
    findlogfiles
    build_worklists
    do_work

    update_report index.html         0         ""
    update_report failed_latest.html $start_ms ((Failed)|(Error))
    update_report failed.html        0         ((Failed)|(Error))

    if {[info exists env(TIMING)]} {
        puts "All elapsed = [expr [clock milliseconds] - $start]"
    }
    catch {unset has_found}
}

