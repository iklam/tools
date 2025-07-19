JAVA=$1
shift

$JAVA -XX:DumpLoadedClassList=Concat0.classlist -cp Concat0.jar Concat0
$JAVA -Xshare:dump -XX:SharedClassListFile=Concat0.classlist -cp Concat0.jar -XX:SharedArchiveFile=Concat0.jsa
$JAVA -XX:SharedArchiveFile=Concat0.jsa -cp Concat0.jar Concat0
