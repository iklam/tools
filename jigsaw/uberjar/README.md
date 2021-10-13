# Quick-and-dirty Demo of Loading Jigsaw Modules from a single JAR file

This is a quick-and-dirty demo. It's not meant to be used in production.

This demo is written for the e-mail discussion thread [Alternative to fatJar - modular solution](https://mail.openjdk.java.net/pipermail/jigsaw-dev/2021-October/014728.html) on the jigsaw-dev mailing list.

Uber-JAR Files (or Fat JAR Files) are a way to distribute a Java application and all of its
dependent libraries in a single JAR file, so that the app can be distributed and executed
easily like:

    java -jar myapp.jar

For example, if the application depends on the Log4J library, the app's main JAR file (myapp.jar)
will embed the Log4J library in an entry like /libs/log4j1.2.17.jar.

Uber-JAR files are supported by popular frameworks, such as SpringBoot. However, many of
these frameworks do not support Jigsaw modules. Hence, I am writing a simple demo
that shows the Java core APIs that can be used to load Jigsaw modules from an Uber-JAR file.

# Uber-JAR Demo

This is a demo of "embedding JAR files inside a JAR file". However, this is not my recommended approach. Please see "Super-JAR Demo" below.

To see how the single JAR file is packaged:

    $ make list-uber
    jar tf build/apps/uber-launcher.jar | sort | grep -v '/$'
    demo/UberJarModuleFinder.class
    demo/UberJarModuleReader.class
    demo/UberJarModuleReference.class
    demo/UberJarReader$AbstractJarReader.class
    demo/UberJarReader.class
    demo/UberJarReaderDemo.class
    demo/UberJarReaderDemo$MyClassLoader.class
    demo/UberJarReader$EmbeddedJarReader.class
    demo/UberJarReader$SimpleJarReader.class
    demo/UberJarURLConnection.class
    demo/UberJarURLStreamHandler.class
    demo/UberJarURLStreamHandlerFactory.class
    demo/UberLauncher.class
    demo/Utils.class
    META-INF/MANIFEST.MF
    modules/com.complex.jar
    modules/com.lib.jar
    modules/com.simple.jar

To run the demo, do the following:

    make run-simple-with-uber-launcher
    make run-complex-with-uber-launcher

You will see ample traces. Please consult the source code.

In the demo, we have 3 modules:

- [com.simple](src/modules/com.simple/com/simple/Simple.java) (A simple module that has no dependency on other modules
- [com.lib](src/modules/com.lib/com/lib/Lib.java) (A "library" module that exports a simple API)
- [com.complex](src/modules/com.complex/com/complex/Complex.java) (A "commplex" module that depends on the com.lib module)

The above "make" command will package the above module into build/apps/uber-launcher.jar
with contents like this:

- demo/UberLauncher.class
- demo/UberJarReaderDemo
- demo/Utils.class ...
- modules/com.complex.jar
- modules/com.lib.jar
- modules/com.simple.jar

[UberLauncher.java](src/apps/uber-launcher/UberLauncher.java) is used to load modules embedded in the "/modules/" directory and execute their main classes.

# Java Core APIs for Module Support

To understand the core APIs needed to support the loading of modules:

    make run-simple-with-path-launcher

[PathLaunch.java](src/apps/path-launcher/PathLauncher.java) shows how to use ModuleFinder, ModuleLayer, etc, to bring everything together.

# Uber-JAR URL Protocol Handler

Some popular frameworks expose the contents of the Uber-JARs using the "jar:" protocol. E.g., 

    jar:file:build/apps/uber-launcher.jar!/modules/com.simple.jar!/com/simple/myresource.txt

However, this would require overridding the built-in "jar:" protocol handler. For convenience,
this demo uses a new protocol "ujar:". E.g.,

    ujar:file:build/apps/uber-launcher.jar!/modules/com.simple.jar!/com/simple/myresource.txt

The implementation of the "ujar:" protocol handler is in [UberJarReader.java](src/apps/uber-launcher/UberJarReader.java). It's simple but
inefficient.

To understand how UberJarReader works:

    make run-uber-jar-reader-demo

# Super-JAR Demo

I would recommend using this approach for packaging a modularized app into a single file.

This is a simplified version of the Uber-JAR demo. Instead of storing modules as JAR files embedded in JAR files, the "exploded" version of the modules are stored:

    $ make list-super
    jar tf tf build/apps/super-launcher.jar | sort | grep -v '/$'
    demo/SuperJarModuleFinder.class
    demo/SuperJarModuleReader.class
    demo/SuperJarModuleReference.class
    demo/SuperLauncher.class
    META-INF/MANIFEST.MF
    modules/com.complex/com/complex/Complex.class
    modules/com.complex/com/complex/myresource.txt
    modules/com.complex/META-INF/MANIFEST.MF
    modules/com.complex/module-info.class
    modules/com.lib/com/lib/Lib.class
    modules/com.lib/com/lib/libresource.txt
    modules/com.lib/META-INF/MANIFEST.MF
    modules/com.lib/module-info.class
    modules/com.simple/com/simple/myresource.txt
    modules/com.simple/com/simple/Simple.class
    modules/com.simple/com/simple/Simple$Foo.class
    modules/com.simple/META-INF/MANIFEST.MF
    modules/com.simple/module-info.class

The advantage is now we can use the JDK's built-in JAR URL Handler. There's no need to define our own "ujar:" URL anymore:

    make run-simple-with-super-launcher
    make run-complex-with-super-launcher

The apps (com.simple and com.complex) work the same way as in the Uber-JAR Demo. However, from the traces
you can see that the classes are loaded from a location that can be expressed by a standard URI:

    SuperJarModuleReader.open com/lib/Lib.class @
        jar:file:///tmp/apps/super-launcher.jar!/modules/com.lib/com/lib/Lib.class

Please see the source file [SuperLauncher.java](src/apps/super-launcher/SuperLauncher.java) for details.
