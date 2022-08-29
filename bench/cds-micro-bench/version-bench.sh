#! /bin/bash
#
# This script runs "java -Xint --version" to measure the JVM bootstrap
# performance. JIT compiler is disabled to avoid large timing variations.
# ----------------------------------------------------------------------
#
# Usage:
#
#     (1) Run each JDK with "perf stat -r 40", once
#     bash version-bench.sh /before/images/jdk /after/images/jdk            | tee log.txt
#
#     (2) Run each JDK with "perf stat -r 100", once
#     bash version-bench.sh /before/images/jdk /after/images/jdk 100        | tee log.txt 
#
#     (3) Run each JDK with "perf stat -r 40", and repeat 10 times (interleaved)
#     bash version-bench.sh /before/images/jdk /after/images/jdk 40 10      | tee log.txt
#
# To visualize the results
#
# $ cat log.txt | tclsh perf_stat_to_csv.tcl 
# 55101060,54555278,40.148,39.274,
# 54513477,54614833,39.960,38.703,
# 54420643,55726368,40.136,38.341,
# 54652727,53016847,39.991,38.354,
# 56174504,53807638,40.011,38.105,
# 52481581,54230684,40.187,38.968,
# 55596496,54633302,40.616,40.047,
# 55360759,55413764,39.994,38.371,
# 55123680,56137379,39.165,37.675,
# 56837671,54793507,38.604,38.143,
# Results of " perf stat -r 40 bin/java -Xshare:on -XX:SharedArchiveFile=jdk2.jsa -Xint --version "
#    1:     55101060    54555278 ( -545782)      -         40.148    39.274 ( -0.874)      --    
#    2:     54513477    54614833 (  101356)                39.960    38.703 ( -1.257)      ---   
#    3:     54420643    55726368 ( 1305725)   +++          40.136    38.341 ( -1.795)      ----- 
#    4:     54652727    53016847 (-1635880)      ---       39.991    38.354 ( -1.637)      ----  
#    5:     56174504    53807638 (-2366866)      -----     40.011    38.105 ( -1.906)      ----- 
#    6:     52481581    54230684 ( 1749103)  ++++          40.187    38.968 ( -1.219)      ---   
#    7:     55596496    54633302 ( -963194)      --        40.616    40.047 ( -0.569)      -     
#    8:     55360759    55413764 (   53005)                39.994    38.371 ( -1.623)      ----  
#    9:     55123680    56137379 ( 1013699)    ++          39.165    37.675 ( -1.490)      ----  
#   10:     56837671    54793507 (-2044164)      ----      38.604    38.143 ( -0.461)      -     
# ============================================================
#           55014977    54686072 ( -328905)      -         39.877    38.593 ( -1.285)      ---   
# instr delta =      -328905    -0.5978%
# time  delta =       -1.285 ms -3.2217%

set -x
export JDK1=$1; shift
export JDK2=$1; shift
repeat=$1; shift
loops=$1; shift

if test ! -f $JDK1/bin/java || test ! -f $JDK2/bin/java; then
    echo wrong usage. please read this script: $0
    exit 1
fi

if test "$repeat" = ""; then
    repeat=40
fi

if test "$loops" = ""; then
    loops=1
fi

function setvars () {
    if test "$1" = 1; then
        export JAVA=$JDK1/bin/java
        export JSA=jdk1.jsa
    else
        export JAVA=$JDK2/bin/java
        export JSA=jdk2.jsa
    fi
}

if test "$NODUMP" != "true"; then
    for i in 1 2; do
        setvars $i
        $JAVA -Xshare:dump -XX:SharedArchiveFile=$JSA
    done
fi

echo Syncing disk .....
sync
sleep 1
sync
sleep 1

for loop in $(seq 1 $loops); do
    for i in 1 2; do   
        true ========================================$loop.$i
        setvars $i
        (perf stat -r $repeat $JAVA -Xshare:on -XX:SharedArchiveFile=$JSA -Xint --version > /dev/null) 2>&1
    done
done

