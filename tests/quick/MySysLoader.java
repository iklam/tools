/*

$ java -cp MySysLoader.jar -Djava.system.class.loader=MySysLoader -Dtest.jar=HelloWorld.jar HelloWorld
[0.002s][warning][cds] Archived non-system classes are disabled because the java.system.class.loader property is specified (value = "MySysLoader"). To use archived non-system classes, this property must not be set
MySysLoader: loadClass("java.lang.Object", false) = loaded by parent loader
MySysLoader: loadClass("HelloWorld", false) = loaded by me
MySysLoader: loadClass("java.lang.String", false) = loaded by parent loader
MySysLoader: loadClass("java.lang.System", false) = loaded by parent loader
MySysLoader: loadClass("java.io.PrintStream", false) = loaded by parent loader
Hello World


$ java -XX:AOTCacheOutput=foo.aot -cp MySysLoader.jar -Djava.system.class.loader=MySysLoader -Dtest.jar=HelloWorld.jar HelloWorld
$ tbjava -XX:AOTCacheOutput=foo.aot -cp MySysLoader.jar -Djava.system.class.loader=MySysLoader -Dtest.jar=HelloWorld.jar HelloWorld
MySysLoader: loadClass("java.lang.Object", false) = loaded by parent loader
MySysLoader: loadClass("HelloWorld", false) = loaded by me
MySysLoader: loadClass("java.lang.String", false) = loaded by parent loader
MySysLoader: loadClass("java.lang.System", false) = loaded by parent loader
MySysLoader: loadClass("java.io.PrintStream", false) = loaded by parent loader
Hello World
Temporary AOTConfiguration recorded: foo.aot.config
Launching child process /jdk3/bld/vox/images/jdk/bin/java to assemble AOT cache foo.aot using configuration foo.aot.config
Picked up JAVA_TOOL_OPTIONS: -Djava.class.path=MySysLoader.jar -Djava.system.class.loader=MySysLoader -Dtest.jar=HelloWorld.jar -XX:AOTCacheOutput=foo.aot -XX:AOTConfiguration=foo.aot.config -XX:AOTMode=create
[0.003s][warning][aot] Archived non-system classes are disabled because the java.system.class.loader property is specified (value = "MySysLoader"). To use archived non-system classes, this property must not be set
Reading AOTConfiguration foo.aot.config and writing AOTCache foo.aot
MySysLoader: loadClass("java.lang.System", false) = loaded by parent loader
MySysLoader: loadClass("java.lang.Object", false) = loaded by parent loader
[...]
MySysLoader: loadClass("MySysLoader", false) = loaded by parent loader
[0.043s][error  ][aot] Unable to resolve class from CDS archive: MySysLoader
[0.043s][error  ][aot] Expected: 0x00000000132ab760, actual: 0x0000000014041000
[0.043s][error  ][aot] Please check if your VM command-line is the same as in the training run
[0.043s][error  ][aot] An error has occurred while writing the shared archive file.
[0.233s][error][aot] Child process failed; status = 1









*/


import java.io.File;
import java.net.URLClassLoader;
import java.net.URL;

public class MySysLoader extends URLClassLoader {
    static private URL[] initURLs() {
        try {
            String jar = System.getProperty("test.jar");
            URL url = new File(jar).toURI().toURL();
            URL[] urls = new URL[] {url};
            return urls;
        } catch (Throwable t) {
            t.printStackTrace();
            System.exit(1);
            return null;
        }
    }


    public MySysLoader(ClassLoader parent) {
        super(initURLs(), parent);
    }

    public Class<?> loadClass(String name, boolean resolve)
        throws ClassNotFoundException
    {
        Class<?> c = super.loadClass(name, resolve);
        String who = (c.getClassLoader() == this) ? "me" : "parent loader";
        System.out.println("MySysLoader: loadClass(\"" + name + "\", " + resolve + ") = loaded by " + who);
        return c;
    }
}
