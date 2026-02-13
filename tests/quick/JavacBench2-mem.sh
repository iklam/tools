JAVA=$1


for coh in - +; do


    $JAVA -cp /home/iklam/tmp/JavacBench2.jar -XX:AOTCacheOutput=jb2.aot -XX:${coh}UseCompactObjectHeaders -Xlog:aot JavacBench2


    for i in {1..10}; do
        true echo $i=$coh
    done

done
