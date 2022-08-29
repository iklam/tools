# source this file into your ~/.bashrc
#
# You need to set IOIGIT to the root of this repo

#======================================================================
# Open files in emacs
#======================================================================

# Quick Edit (in emacs)
alias qe='qq -nofind'

# Quick Quick (edit in emacs)
# qq = confirmation needed if file has changed on disk
# qw = open in github (web)
# qqq = no ask. Any edits have been lost.
# qqclip = open the file in the clipboard text
alias qq='tclsh ${IOIGIT}/scripts/myide/qq.tcl'
alias qw='tclsh ${IOIGIT}/scripts/myide/qq.tcl -w'
alias qqq='REVERT=1 qq'
alias qqclip='tclsh ${IOIGIT}/scripts/myide/qq-clipboard.tcl'

complete -F __qq_complete qq
complete -F __qq_complete qw
complete -F __qq_complete re
complete -F __qq_complete whoincludes
complete -F __qq_complete wi10
complete -F __qq_complete wi

#function __qq_complete () {
#    local i
#    for i in $(tclsh ${IOIGIT}/scripts/qq_complete.tcl "${COMP_WORDS[1]}"); do
#        COMPREPLY+=($i)
#    done
#}

function __qq_complete () {
    COMPREPLY=($(tclsh ${IOIGIT}/scripts/myide/qq_complete.tcl "${COMP_WORDS[1]}"))
}

#======================================================================
# More GUI interations with emacs
#======================================================================

alias grepedit='wish ${IOIGIT}/scripts/myide/grep_edit.tcl'
# grep -lr java_lang_VirtualThread . | grep -v '~' | sort | grepedit

#======================================================================
# More GUI interations with Gnome Terminal
#======================================================================

alias wins='tclsh $IOIGIT/scripts/myide/show_terminal_windows.tcl $GNOME_TERNIMAL_NAME'

#======================================================================
# Header files
#======================================================================

function whoincludes () {
    (cd0 &&
         tclsh ${IOIGIT}/headers/whoincludes.tcl "$@"
    )
}

function wi10 () {
    whoincludes "$@" | head -10
}

alias wi=wi10
