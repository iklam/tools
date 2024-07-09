LEYDEN = /jdk3/bld/le4/images/jdk/bin/java
MAINLINE = /jdk3/bld/rum/images/jdk/bin/java

HelloWorld.jar: HelloWorld.java
	javac HelloWorld.java
	jar cf HelloWorld.jar HelloWorld.class

FLAGS = -XX:-ArchiveDynamicProxies \
        -XX:-ArchiveLoaderLookupCache \
        -XX:-ArchivePackages \
        -XX:-ArchiveReflectionData

HelloWorld.old.classlist: HelloWorld.jar
	${MAINLINE} -Xshare:off -XX:DumpLoadedClassList=HelloWorld.old.classlist -cp HelloWorld.jar HelloWorld

HelloWorld.new.classlist: HelloWorld.jar
	${LEYDEN} -Xshare:off -XX:DumpLoadedClassList=HelloWorld.new.classlist -cp HelloWorld.jar HelloWorld

old.jsa: HelloWorld.jar HelloWorld.old.classlist
	${MAINLINE} -Xshare:dump -cp HelloWorld.jar -XX:SharedClassListFile=HelloWorld.old.classlist -XX:SharedArchiveFile=$@

old: old.jsa
	${MAINLINE} -Xshare:on -XX:SharedArchiveFile=old.jsa -cp HelloWorld.jar HelloWorld

new.jsa: HelloWorld.jar HelloWorld.new.classlist
	${LEYDEN} -Xshare:dump -cp HelloWorld.jar -XX:SharedClassListFile=HelloWorld.new.classlist -XX:SharedArchiveFile=$@ \
		-XX:+PreloadSharedClasses -XX:+ArchiveInvokeDynamic ${FLAGS}

new: new.jsa
	${LEYDEN} -Xshare:on -XX:SharedArchiveFile=new.jsa -cp HelloWorld.jar HelloWorld


bench: old new
	rm -f log.txt
	for i in 1 2 3 4 5 6 7 8 9 10; do \
		perf stat -r 40 ${MAINLINE} -Xshare:on -XX:SharedArchiveFile=old.jsa -cp HelloWorld.jar HelloWorld 2>&1 | cat >> log.txt; \
		perf stat -r 40 ${LEYDEN} -Xshare:on -XX:SharedArchiveFile=new.jsa -cp HelloWorld.jar HelloWorld 2>&1 | cat >> log.txt; \
	done

perf:
	tclsh ../../bench/cds-micro-bench/perf_stat_to_csv.tcl < log.txt 

clean:
	rm -f *.class *.classlist *.jsa *.jar log.txt *~

