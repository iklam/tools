# this is a version of qq.tcl that opens the highlighted file inside emacs. It is activated via
# xbindkeys -- see https://www.linux.com/news/start-programs-pro-xbindkeys
#
# To configure the keyboard shortcut, run xbindkeys-config
# I am binding it to control+b:3, which means ctrl+mouse-left-button

source [file dirname [info script]]/../lib/xraise.tcl

set DEBUG 1
set logfd stdout

if {[info exists env(TEST_QQ)]} {
    set logfd stdout
} else {
    if {$DEBUG} {
        #catch {set logfd [open /dev/pts/7 w+]; puts $logfd "Using $logfd"}
        catch {set logfd [open /tmp/qqclip-debug w+]; puts $logfd "Using $logfd"}
    }
    #set logfd [open /dev/pts/8 w+]
}

proc log {str} {
    global logfd env
    if {[info exists logfd]} {
        catch {
            puts $logfd "$str\r"
            flush $logfd
        }
    }
}

# for quick testing

set text [lindex $argv 0]
if {"$text" == ""} {
    set text [string trim [exec xclip -o]]
}
if {$text == ""} {
    log "no input in clipboard (xclip)"
    exit
}

regsub "^at " $text "" text

regsub "^#  Internal Error \\(" $text "" text
regsub "\\), pid=" $text " " text

if {[regexp {[(]([A-Za-z0-9_]+[.]java:[0-9]+)[)]} $text dummy fileline]} {
    set text "$fileline"
} else {
    regexp {.* ([/0-9a-zA-Z_.]+:[0-9]+)} $text dummy text
    if {[regexp {file ([/0-9a-zA-Z_.]+), line ([0-9]+)} $text dummy file line]} {
        set text "$file:$line"
    }
}

log "QQ text = $text"

set env(NO_NEW_FILES) 1

proc find_focus_win {} {
    
}

#regsub :.* $text "" test

proc try_dir {text dir} {
    global env

    regsub :.* $text "" text
    set dir $env(REPO_ROOT)/$dir

    log $dir/$text

    if {[file exists $dir/$text]} {
        cd $dir
        return 1
    } else {
        return 0
    }
}

proc try_xpwd {text xwin} {
    log "trying xpwd $xwin"
    set good 0
    if {[catch {
        set data [exec xprop -id $xwin]
        if {[regexp {IOI_PWD.STRING. = "([^\"]+)"} $data dummy pwd]} {
            regsub :.* $text "" text
            log IOI_PWD.STRING=$pwd
            log $pwd/$text
            if {[file exists $pwd/$text]} {
                cd $pwd
                set good 1
            }
        } else {
            log huh?
        }
    } err]} {
        log $err
    }

    log xpwd=$good

    return $good
}

if {[regexp ^/ $text]} {
    if {[regexp {^(/[^:]*):([0-9]+)} $text dummy file line]} {
        # This is a file inside gdb
        edit_in_emacs $file +$line
    } elseif {[regexp {^(/[^ ,:]+)} $text dummy file]} {
        # This is a file inside gdb
        edit_in_emacs $file
        exit
    }
} else {
    if {[catch {
        if {![info exists env(REPO_ROOT)] || $env(REPO_ROOT) == ""} {
            # We are probably running with Ctrl-btn-3
            set fd [open /tmp/autoraise-active-term]
            set line [gets $fd]
            set line [gets $fd]
            set repo [lindex $line end]
            set xwin [lindex $line 0]
            close $fd
            log $line
            log $repo
            if {[file exists /jdk3/$repo]} {
                set env(REPO_ROOT) /jdk3/$repo
            } elseif {[file exists /jdk2/$repo]} {
                set env(REPO_ROOT) /jdk2/$repo
            } elseif {[file exists /jdk/$repo]} {
                set env(REPO_ROOT) /jdk/$repo
            } else {
                exit
            }

            if {![try_xpwd $text $xwin] &&
                ![try_dir $text open/src/hotspot] &&
                ![try_dir $text open/src/hotspot/shared] &&
                ![try_dir $text open/src]} {
                cd $env(REPO_ROOT)/open/src/java.base
            }

            if {![regexp {[./]} $text] && [regexp {^[A-Z]} $text] && ![file exists $text]} {
                # This is probably the name of a Java class
                set text $text.java
            }

            # java.lang.invoke.InvokerBytecodeGenerator.generateCustomizedCode(java.base@20-internal/InvokerBytecodeGenerator.java:749)
            # ->
            # InvokerBytecodeGenerator.java:749
            regexp {[^ ]*[\(][a-z.]*@[^/]+/([A-Za-z0-9_]+[.]java:[0-9]+)} $text dummy text

            log "opening with qq: pwd = [pwd]" 
            log "opening with qq: $text" 
        }
        log "Running QQ \"$text\" in [pwd]"
        exec tclsh [file dirname [info script]]/qq.tcl $text 2>@ $logfd >@ $logfd
    } err]} {
        log $err
    }
}


