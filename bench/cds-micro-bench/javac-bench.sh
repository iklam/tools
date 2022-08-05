# This script runs javac with a custom CDS archive, to test how CDS supports classes
# loaded by the AppClassLoader.
# ----------------------------------------------------------------------
#
# Usage:
#
#     (1) Run each JDK with "perf stat -r 40", once
#     bash javac-bench.sh /before/images/jdk /after/images/jdk            | tee log.txt
#
#     (2) Run each JDK with "perf stat -r 100", once
#     bash javac-bench.sh /before/images/jdk /after/images/jdk 100        | tee log.txt 
#
#     (3) Run each JDK with "perf stat -r 40", and repeat 10 times (interleaved)
#     bash javac-bench.sh /before/images/jdk /after/images/jdk 40 10      | tee log.txt
#
# To visualize the results
#
# $ cat log.txt | tclsh perf_stat_to_csv.tcl 

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

HELLO_WORLD_JAVA=Bench_HelloWorld.java

cat > $HELLO_WORLD_JAVA <<EOF
public class Bench_HelloWorld {
    public static void main(String args[]) {
      System.out.println("Hello World");
    }
}
EOF

function setvars () {
    if test "$1" = 1; then
        export JAVAC=$JDK1/bin/javac
        export JAVA=$JDK1/bin/java
        export JSA=javac1.jsa
    else
        export JAVAC=$JDK2/bin/javac
        export JAVA=$JDK2/bin/java
        export JSA=javac2.jsa
    fi
}

if test "$NODUMP" != "true"; then
    for i in 1 2; do
        setvars $i
        $JAVAC -J-Xshare:off -J-XX:DumpLoadedClassList=javac.classlist.$i $HELLO_WORLD_JAVA
        $JAVA -Xshare:dump -XX:SharedArchiveFile=$JSA -XX:SharedClassListFile=javac.classlist.$i -Xlog:cds=debug | tee dump.$i.log
    done
fi

for loop in $(seq 1 $loops); do
    for i in 1 2; do   
        true ========================================$loop.$i
        setvars $i
        perf stat -r $repeat $JAVAC -J-Xshare:on -J-XX:SharedArchiveFile=$JSA $HELLO_WORLD_JAVA 2>&1
    done
done

