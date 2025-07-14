# source this file into your ~/.bashrc
#
# You need to set IOIGIT to the root of this repo

alias tools='cd ${IOIGIT}'

#======================================================================
# GIT
#======================================================================

alias gitref='git commit -a --amend --date=now --no-edit --reset-author'
alias gitout='git log origin/master..'
#alias gitout='git log --branches --not --remotes=origin'
alias gitb='git branch'
alias gitsw='git switch'
alias gitst='git status'
alias gitstt='git status .'
alias gitcp='git cherry-pick'
alias gitl='git log'
alias gitbh='tclsh ${IOIGIT}/scripts/scm/git_branch_hierarchy.tcl'
alias gitds='git diff --stat'
alias gitcp='git cherry-pick'
alias gitcpc='git cherry-pick --continue'
alias gitbranches='tclsh ${IOIGIT}/scripts/scm/gitbranches.tcl'
alias gitblame='tclsh ${IOIGIT}/scripts/scm/gitblame.tcl'
alias gitweb='tclsh ${IOIGIT}/scripts/scm/gitweb.tcl'
alias gitswtc='git switch --track=direct -c'
alias grepjar='tclsh ${IOIGIT}/scripts/misc/grepjar.tcl'
alias gittodos='gitdiffgrep master "(TODO)|(FIXME)"'


function gitdiffgrep () {
    local pat=$1
    if test "$2" != ""; then
        pat=$2;
    fi
    pat="(^[+][+])|($pat)"
    sed="s/^[+][+][+] b./+++ /g"
    if test "$2" != ""; then
        git diff $1 | sed -e "$sed" | egrep $pat
    else
        git diff | egrep $pat
    fi
}

# gitrevert master src/hotspot/share/cds/archiveBuilder.cpp
# alias gvm='gitrevert master'
function gitrevert () {
    if git show $1:$2 > /tmp/gitrevert.tmp; then
        mv /tmp/gitrevert.tmp $2
        echo updated $2 to version $1
    else
        rm -f /tmp/gitrevert.tmp
        echo usage $0 version file
    fi
}

# Used for diffing two diff files
alias filterdiff='tclsh ${IOIGIT}/scripts/scm/filter_diff.tcl'

function is-in-leyden () {
    if git branch | grep -q premain; then
        return 0
    else
        return 1
    fi
}

function git-refresh () {
    if is-in-leyden; then
        local parent=premain
    else
        local parent=master
    fi

    if git branch | grep -q "[*] $parent"; then
    (
        (set -x; git branch) || return;
        (set -x; git status) || return;
        read -p "Are you sure? [yN] " -n 1 -r
        echo    # (optional) move to a new line
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo skipped
            return
        fi
        (set -x; git pull upstream $parent) || return;

        (set -x; git push origin)
    )
    else
        echo "You are not on $parent branch??"
    fi
}

function current-branch () {
    (
        cdo
        echo $(git branch | grep '[*]' | cut -b 3-)-$(git log -1 | head -1 | sed -e 's/commit //' -e 's/ /-/g')
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
#alias qqq='REVERT=1 qq'
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

#======================================================================
# jjrun - run commands with my JDK build
#======================================================================

# launcher used by jjrun
function get_launcher () {
    if test "$LAUNCHER" != ""; then
        echo $LAUNCHER
    else
        echo d
    fi
}

function show_launcher () {
    local LL=$(get_launcher)
    if test "$LL" = "p"; then
        echo $TBP
    elif test "$LL" = "d"; then
        echo $TBD
    elif test "$LL" = "fd"; then
        echo $TBFD
    elif test "$LL" = ""; then
        echo $TBJAVA
    else
        echo $TBJAVA
    fi
}

function jjrun () {
    local launcher=$(get_launcher)
    local noop=0
    local verbose=1
    # -n means print out the command line but don't do anything
    if test "$1" = "-n"; then
        shift
        noop=1
    fi
    if test "$1" = "-q"; then
        shift
        verbose=1
    fi

    local cmds=$(tclsh ${IOIGIT}/scripts/myide/jjrun_shuffle_args.tcl "$@")
    if test $noop = 1; then
        echo "$launcher $cmds"
    else
        if test $verbose = 1; then
            echo "$launcher $cmds"
        fi
        eval "$launcher $cmds"
    fi
}

# javac - premain "old" workflow
function oldjavac0 () {
    jjrun "$@" --- -Xshare:off -XX:DumpLoadedClassList=javac.classlist com.sun.tools.javac.Main ~/tmp/HelloWorld.java
}
function oldjavac1 () {
    jjrun "$@" --- -Xlog:cds=debug -XX:+ArchiveInvokeDynamic -Xshare:dump -XX:SharedArchiveFile=javac.jsa -XX:SharedClassListFile=javac.classlist
}

#==================================================================================
# cdsrun - a uniform way for running handly CDS test cases (HelloWorld, javac, etc)
#=================================================================================
function cdsrun () {
    local testname=$1
    local testcp=$2
    local testmain=$3
    local testmode=$4

    shift; shift; shift; shift;

    local hasgdb=0
    local hasperf=0
    local perfrepeat=
    local args0=
    local args1=
    local args2=
    local i
    local whicharg=0

    for i in "$@"; do
        if test "$i" = "--"; then
            whicharg=$(expr $whicharg + 1)
        else
            if test "$whicharg" = "0"; then
                if [[ "$arg0" = "" ]] && [[ $hasgdb = "0" ]] && [[ "$i" = "-gdb" ]]; then
                    hasgdb=1
                elif [[ "$arg0" = "" ]] && [[ $hasperf = "0" ]] && [[ "$i" = "-perf" ]]; then
                    hasperf=1
                elif [[ "$arg0" = "" ]] && [[ $hasperf = "1" ]] && [[ "$perfrepeat" = "" ]]; then
                    # TODO: check for error
                    perfrepeat=$i
                else
                    args0="$args0 $i"
                fi
            elif test "$whicharg" = "1"; then
                args1="$args1 $i"
            else
                args2="$args2 $i"
            fi
        fi
    done


    if test $hasgdb = 1; then
        if [[ "$TESTBED/bin/java" = "$LAUNCHER" ]]; then
            local cmd="gdb --args $LAUNCHER $args0"
        else
            local cmd="$LAUNCHER -gdb $args0"
        fi
    elif test $hasperf = 1; then
        if [[ "$TESTBED/bin/java" = "$LAUNCHER" ]]; then
            local cmd="perf stat -r $perfrepeat $LAUNCHER $args0"
        else
            local cmd="$LAUNCHER -gdb $args0"
        fi
    else
        local cmd="$LAUNCHER $args0"
    fi

    if test "$testcp" != ""; then
        cmd="$cmd -cp $testcp"
    fi

    local NEW_WF_ARGS=""
    local LOG_CDS="-Xlog:aot,cds"
    if test "$NO_LOG_CDS" != ""; then
        LOG_CDS=""
    fi
    case "$testmode" in
        none)
            # none = run the app as is, without any app-specific CDS optimizations
            true
            ;;
        old0)
            # old0 = old workflow: dump classlist for static archive
            cmd="$cmd -Xshare:off -XX:DumpLoadedClassList=$testname.classlist"
            ;;
        old1)
            # old1 = old workflow: dump static archive
            cmd="$cmd -Xshare:dump $LOG_CDS -XX:SharedArchiveFile=$testname.jsa -XX:SharedClassListFile=$testname.classlist"
            ;;
        old2)
            # old1 = old workflow: run with static archive
            cmd="$cmd -Xshare:on -XX:SharedArchiveFile=$testname.jsa"
            ;;
        preload01)
            # JEP 514
            cmd="$cmd -XX:AOTMode=record -XX:AOTCacheOutput=$testname.aot -Xlog:cds"
            ;;
        preload0)
            # old0 = old workflow: dump classlist for static archive
            cmd="$cmd -XX:AOTMode=record -XX:AOTConfiguration=$testname.aotconfig"
            ;;
        preload1)
            # Preload 1 = old static workflow with class preloading: dump static archive
            cmd="$cmd -XX:AOTMode=create $LOG_CDS -XX:AOTCache=$testname.aot -XX:AOTConfiguration=$testname.aotconfig"
            ;;
        preload2)
            # Preload 2 = old static workflow with class preloading: run with static archive
            cmd="$cmd -XX:AOTMode=on -XX:AOTCache=$testname.aot"
            ;;
        preload3)
            # Preload 3 = re-train with an existing AOT cache
            cmd="$cmd -XX:AOTMode=record -XX:AOTConfiguration=$testname.aotconfig -XX:AOTCache=$testname.aot"
            ;;
        dpreload0)
            # Dynamic Preload 0 = old dynamic workflow with class preloading: dump dynamic archive
            cmd="$cmd -XX:+AOTClassLinking -XX:ArchiveClassesAtExit=$testname.dp.jsa"
            ;;
        dpreload1)
            # Dynamic Preload 1 = old dynamic workflow with class preloading: run with dynamic archive
            cmd="$cmd -XX:SharedArchiveFile=$testname.dp.jsa"
            ;;
        new0)
            # new0 = new workflow: dump preimage
            rm -vf $testname.cds
            rm -vf $testname.cds.preimage
            cmd="$cmd $LOG_CDS ${NEW_WF_ARGS} -XX:+UnlockDiagnosticVMOptions"
            cmd="$cmd -XX:+CDSManualFinalImage -XX:CacheDataStore=$testname.cds"
            ;;
        new1)
            # new1 = new workflow: dump final image
            cmd="$cmd $LOG_CDS ${NEW_WF_ARGS} -XX:CDSPreimage=$testname.cds.preimage -XX:CacheDataStore=$testname.cds"
            ;;
        newd)
            rm -vf $testname.cds
            rm -vf $testname.cds.preimage
            # newd = new workflow: dump (with a single command)
            cmd="$cmd $LOG_CDS ${NEW_WF_ARGS} -XX:CacheDataStore=$testname.cds"
            ;;
        new2)
            # new2 = new workflow: use final image
            cmd="$cmd $LOG_CDS ${NEW_WF_ARGS} -XX:CacheDataStore=$testname.cds"
            ;;
    esac

    cmd="$cmd $args1 $testmain $args2"

    echo $cmd >&2
    eval $cmd
}


function cdsrun-define () {
    local testname=$1
    local testcp=$2
    local testmain=$3

    local run="cdsrun \"$1\" \"$2\" \"$3\""

    alias ${testname}0="$run none"

    alias ${testname}o0="$run old0"
    alias ${testname}o1="$run old1"
    alias ${testname}o2="$run old2"

    # Preloaded (static)
    alias ${testname}p01="$run preload01"
    alias ${testname}p0="$run preload0"
    alias ${testname}p1="$run preload1"
    alias ${testname}p2="$run preload2"
    alias ${testname}p3="$run preload3"

    # Preloaded (dynamic)
    alias ${testname}dp0="$run dpreload0"
    alias ${testname}dp1="$run dpreload1"

    alias ${testname}n0="$run new0"
    alias ${testname}n1="$run new1"
    alias ${testname}n01="$run new0 && $run new1"
    alias ${testname}nd="$run newd"
    alias ${testname}n2="$run new2"
}

cdsrun-define vv "" --version
cdsrun-define hw ~/tmp/HelloWorld.jar HelloWorld
cdsrun-define hc ~/tmp/HelloCustom.jar HelloCustom
cdsrun-define hl ~/tmp/HelloLambda.jar HelloLambda
cdsrun-define mh ~/tmp/HelloMH.jar HelloMH
cdsrun-define st ~/tmp/StreamTest.jar StreamTest
cdsrun-define pd ~/tmp/PDTest.jar PDTest
cdsrun-define pl ~/tmp/PreloadTest.jar PreloadTest
cdsrun-define pk ~/tmp/PkgTest.jar test.pkg.PkgTest
cdsrun-define xx ~/tmp/jdk-8290417/test.jar Test
cdsrun-define mt ~/tmp/MyTest.jar MyTest
cdsrun-define pk ~/tmp/PackageTest.jar test.pkg.PackageTest
cdsrun-define md "" "-p ${HOME}/tmp/modules/ioi/app.jar:${HOME}/tmp/modules/ioi/dir -m app/app.Main"
cdsrun-define jc "" "com.sun.tools.javac.Main -d . ~/tmp/HelloWorld.java"
cdsrun-define ss $TESTBED/demo/jfc/SwingSet2/SwingSet2.jar SwingSet2




