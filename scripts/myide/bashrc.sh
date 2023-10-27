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
alias gitcp='git cherry-pick'
alias gitl='git log'
alias gitbh='tclsh ${IOIGIT}/scripts/scm/git_branch_hierarchy.tcl'
alias gitds='git diff --stat'
alias gitcp='git cherry-pick'
alias gitcpc='git cherry-pick --continue'
alias gitbranches='tclsh ${IOIGIT}/scripts/scm/gitbranches.tcl'
alias gitblame='tclsh ${IOIGIT}/scripts/scm/gitblame.tcl'
alias gitweb='tclsh ${IOIGIT}/scripts/scm/gitweb.tcl'

# Used for diffing two diff files
alias filterdiff='tclsh ${IOIGIT}/scripts/scm/filter_diff.tcl'

function git-refresh () {
    if git branch | grep -q '[*] master'; then
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
    else
        echo "You are not on master branch??"
    fi
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

alias countinc='tclsh ${IOIGIT}/headers/count_hotspot_headers.tcl'
alias incx='(if test ! -d hotspot/variant-server/libjvm/objs; then cdd0; fi; countinc)'
alias incxx='incx | sort -n'
alias incxx4='incxx | tail -4'


#======================================================================
# ls color settings
#======================================================================

# Colors for a dark background
function lscolors-dark () {
    export LS_COLORS="rs=0:di=01;33:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.webp=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:"
}

# Colors for a light background
function lscolors-light () {
    export LS_COLORS="rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.webp=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:"
}
