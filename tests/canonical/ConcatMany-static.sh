JAVA=$1
shift

$JAVA -XX:DumpLoadedClassList=ConcatMany.classlist -cp ConcatMany.jar ConcatMany
$JAVA -Xshare:dump -XX:SharedClassListFile=ConcatMany.classlist -cp ConcatMany.jar -XX:SharedArchiveFile=ConcatMany.jsa -Xlog:cds+heap=error
$JAVA -XX:SharedArchiveFile=ConcatMany.jsa -cp ConcatMany.jar ConcatMany
