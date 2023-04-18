#! /bin/bash
# This script tries to avoid doing unnecessary stuff during JDK builds:
#   + avoid unnecessary copying of libjvm.so
#   + avoids building the gtest binaries when doing an xmd/xmp/xmfd build
#   + support distributed build via ./distcc.tcl
#
# This script needs jdkspecgmkpatch.sh to patch up the spec.gmk

EXTRA0=
EXTRA=
function doln () {
    if test "$(uname)" = "SunOS"; then
        ln $1 $2
    else
        ln -v $1 $2
    fi
}

cmd=$1
shift
case "$cmd" in
    CP)
        if [[ "$1" = "-fP" && "$2" == *"libjvm.so"* && "$3" == *"libjvm.so"* ]]; then
            rm -f $3
            doln $2 $3
            ls -li $2 $3
            exit 0
        fi
        if [[ "$1" == *"libjvm.so"* && "$2" == *"libjvm.so"* ]]; then
            rm -f $2
            doln $1 $2
            ls -li $1 $2
            exit 0
        fi
        ;;
    CXX|LDCXX|BUILD_CXX|BUILD_LDCXX)
        xcmd=$cmd
        last=
       if [[ "$bldtype" != "" ]]; then
        for i in "$@"; do
            #echo "$last -$i-"

            regex='((/gtest/libjvm.so)|(/gtest/gtestLauncher))$'
            if [[ $i =~ $regex  ]] && [[ "$last" = "-o" ]]; then
                rm -f $i
                touch $i
                echo created dummy $i
                exit 0
            fi
            last=$i
        done
       fi
        if test "$cmd" = "LDCXX"; then
            if test "$(uname)" = "Linux"; then
                if test "$NOGOLD" != "1"; then
                    if [[ "$@" =~ libjvm.so ]]; then
                        EXTRA0=time
                        #EXTRA="-fuse-ld=gold -Wl,--threads,--thread-count,16"
                        echo using hacked lld
                        EXTRA="-fuse-ld=gold -Wl,--threads"
                    fi
                fi
                #EXTRA=
            fi
        fi
        ;;
esac

# Not hacked -- let's exec the original command, but we might run it using distcc
#echo $cmd
cmd=IOI_ORIG_${cmd}
#echo $cmd
cmd=${!cmd}
#echo $cmd
#echo ==$EXTRA0$DISTCC$xcmd==
if test "$EXTRA0$DISTCC$xcmd" = "ioidistccCXX"; then
    DISTCC=distcc
else
    DISTCC=
fi

# (a) echo just the name
if test "$QUIET_BUILD" = ""; then
    #$cmd
    echo $DISTCC: $bldtype $(echo "$@" | sed -e 's/.* //g' -e 's/.*frandom-seed=//g' | sed -e 's/[^ ]*.src.hotspot.//')
fi

# (b) echo the entire cmdline
#set -x

if test "$DISTCC" = "distcc"; then
    exec tclsh /jdk3/tools/scripts/myide/distcc.tcl $cmd $EXTRA "$@"
    # shouldn't come to hete
    exit 2
fi

exec $EXTRA0 $cmd $EXTRA "$@"
