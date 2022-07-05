# From the results of 'grep', make it easy to open a file
#
# Supports this only fo now:
#
# grep -lr java_lang_VirtualThread . | grep -v '~' | sort | wish grep_edit.tcl

package require Tix
set sl [tixScrolledHList .sl -options {
    hlist.columns 2
}]
pack $sl -expand yes -fill both

set hlist [$sl subwidget hlist]
$hlist config -selectforeground black -selectbackground #a0a0ff  -font {{DejaVu Sans Mono} -10} -columns 2 -width 80 -height 40
#$hlist config -browsecmd browse_hlist
#$hlist config -command sync_emacs

bind $hlist <ButtonRelease-1> "hlist_select $hlist %x %y"

set win   [eval tixDisplayStyle window -padx 0 -pady 0 -bg [$hlist cget -bg]]

set n 0
while {![eof stdin]} {
    set line [string trim [gets stdin]]
    if {"$line" ==  ""} {
        continue
    }
    
    incr n
    set selbtn [checkbutton $hlist.check-$n -padx 1 -pady 3 -bg [$hlist cget -bg] -bd 0 -highlightthickness 0]
    #$selbtn config -command save_selection -variable sel_$file

    $hlist add $n -itemtype window -window $selbtn -style $win
    $hlist item create $n 1 -itemtype text -text "$line"

    # set id [label $hlist.${btnname}-id -padx 2 -pady 3 -bg [$hlist cget -bg] -bd 0 -text $btnname -justify left -font $font]
}

set last_index -1
proc hlist_select {hlist x y} {
    set index [$hlist info selection]
    global last_index
    
    #puts $index
    if {$index != {} && $last_index != $index} {
        set selbtn $hlist.check-$index
        $selbtn select
        set file [$hlist item cget $index 1 -text]
        set last_index $index
        catch {
            exec emacsclient -n $file >@ stderr 2>@ stderr
        }
    }
}
