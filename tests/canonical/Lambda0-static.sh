JAVA=$1
shift

$JAVA -XX:DumpLoadedClassList=Lambda0.classlist -cp Lambda0.jar Lambda0
$JAVA -Xshare:dump -XX:SharedClassListFile=Lambda0.classlist -cp Lambda0.jar -XX:SharedArchiveFile=Lambda0.jsa
$JAVA -XX:SharedArchiveFile=Lambda0.jsa -cp Lambda0.jar Lambda0
