JAVA=$1
shift

$JAVA -XX:DumpLoadedClassList=HelloWorld.classlist -cp HelloWorld.jar HelloWorld
$JAVA -Xshare:dump -XX:SharedClassListFile=HelloWorld.classlist -cp HelloWorld.jar -XX:SharedArchiveFile=HelloWorld.jsa
$JAVA -XX:SharedArchiveFile=HelloWorld.jsa -cp HelloWorld.jar HelloWorld
