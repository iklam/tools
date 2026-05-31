#! /bin/bash
#
# This script runs "java -cp HelloWorld.jar HelloWorld" with an AOT cache.
# Because training can be non-determinisic, you should train several times.
# Use case (4) below.
# ----------------------------------------------------------------------
#
# Usage:
#
#     (1) Run each JDK with "perf stat -r 40", once
#     bash aot-hello.sh /before/images/jdk /after/images/jdk            | tee log.txt
#
#     (2) Run each JDK with "perf stat -r 100", once
#     bash aot-hello.sh /before/images/jdk /after/images/jdk 100        | tee log.txt 
#
#     (3) Run each JDK with "perf stat -r 40", and repeat 10 times (interleaved)
#     bash aot-hello.sh /before/images/jdk /after/images/jdk 40 10      | tee log.txt
#
#     (4) Train the AOT cache 5 times. For each cache,
#         Run each JDK with "perf stat -r 80", and repeat 10 times (interleaved)
#     bash aot-hello.sh /before/images/jdk /after/images/jdk 80 10 5    | tee log.txt
#
# To visualize the results
#
# $ cat log.txt | tclsh perf_stat_to_csv.tcl 

set -x
export JDK1=$1; shift
export JDK2=$1; shift
repeat=$1; shift
loops=$1; shift
dumps=$1; shift

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

if test "$dumps" = ""; then
    loops=1
fi

cat > HelloWorld.java <<EOF
// auto-generated
public class HelloWorld {
    public static void main(String args[]) {
        System.out.println("HelloWorld");
    }
}
EOF

$JDK1/bin/javac HelloWorld.java
$JDK1/bin/jar cf HelloWorld.jar HelloWorld.class

function setvars () {
    if test "$1" = 1; then
        export JAVA=$JDK1/bin/java
        export CACHE=hw1.aot
    else
        export JAVA=$JDK2/bin/java
        export CACHE=hw2.aot
    fi
}

function dump() {
    if test "$NODUMP" != "true"; then
        for i in 1 2; do
            setvars $i
            $JAVA -XX:AOTCacheOutput=$CACHE -cp HelloWorld.jar HelloWorld
        done
    fi
    echo Syncing disk .....
    sync
    sleep 1
    sync
    sleep 1
}


for d in $(seq 1 $dumps); do
    dump
    for loop in $(seq 1 $loops); do
        for i in 1 2; do   
            true ========================================$d.$loop.$i
            setvars $i
            (perf stat -r $repeat $JAVA -XX:AOTMode=on -XX:AOTCache=$CACHE -cp HelloWorld.jar HelloWorld  > /dev/null) 2>&1
        done
    done
done

