# source this file into your ~/.bashrc
#
# You need to set IOIGIT to the root of this repo

alias tools='cd ${IOIGIT}'

#======================================================================
# GIT
#======================================================================

alias gitref='git commit -a --amend --date=now --no-edit'
alias gitout='git log origin/master..'
#alias gitout='git log --branches --not --remotes=origin'
alias gitb='git branch'
alias gitsw='git switch'
alias gitst='git status'
alias gitl='git log'
alias gitbh='tclsh ${IOIGIT}/scripts/scm/git_branch_hierarchy.tcl'

alias gitbranches='tclsh ${IOIGIT}/scripts/scm/gitbranches.tcl'
alias gitblame='tclsh ${IOIGIT}/scripts/scm/gitblame.tcl'
alias gitweb='tclsh ${IOIGIT}/scripts/scm/gitweb.tcl'

# Used for diffing two diff files
alias filterdiff='tclsh ${IOIGIT}/scripts/scm/filter_diff.tcl'

function git-refresh () {
    (
        (set -x; git branch) || return;
        (set -x; git status) || return;
        read -p "Are you sure? [yN] " -n 1 -r
        echo    # (optional) move to a new line
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo skipped
            return
        fi
        git pull upstream master || return;

        git push origin
    )
}

function current-branch () {
    (
        cdo
        git branch | grep '[*]' | cut -b 3-
    )
}

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
# Diff
#======================================================================
alias tkdiff='${IOIGIT}/scripts/scm/tkdiff'
alias tksvn='${IOIGIT}/scripts/scm/tksvn'

#======================================================================
# JBS
#======================================================================

alias jbs='tclsh ${IOIGIT}/scripts/misc/jbs_status.tcl'

function git2jbs () {
    local line=$(git log $1 | grep '[0-9][0-9].....:' | head -1)
    echo https://bugs.openjdk.java.net/browse/JDK-$(echo $line | sed -e 's/:.*//g')
    echo "    $(echo $line | sed -e 's/.......://g')"
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

