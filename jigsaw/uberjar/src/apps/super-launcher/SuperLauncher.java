/*
 * Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 *
 */

package demo;

import java.io.*;
import java.lang.module.*;
import java.net.*;
import java.util.*;
import java.util.zip.*;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import java.nio.file.*;

// A simplified version of ../uber-launcher/UberLauncher.java
//
// Instead of storing the modules as JAR files inside a JAR file, we store the exploded version of the modules. E.g.
//
// $ jar tf tf build/apps/super-launcher.jar | sort | grep -v '/$'
// demo/SuperJarModuleFinder.class
// demo/SuperJarModuleReader.class
// demo/SuperJarModuleReference.class
// demo/SuperLauncher.class
// META-INF/MANIFEST.MF
//
// modules/com.complex/com/complex/Complex.class
// modules/com.complex/com/complex/myresource.txt
// modules/com.complex/META-INF/MANIFEST.MF
// modules/com.complex/module-info.class
//
// modules/com.lib/com/lib/Lib.class
// modules/com.lib/com/lib/libresource.txt
// modules/com.lib/META-INF/MANIFEST.MF
// modules/com.lib/module-info.class
//
// modules/com.simple/com/simple/myresource.txt
// modules/com.simple/com/simple/Simple.class
// modules/com.simple/com/simple/Simple$Foo.class
// modules/com.simple/META-INF/MANIFEST.MF
// modules/com.simple/module-info.class
//
// The code source URI of the classes looks like this:
//
// jar:file:{jarfile}/!/modules/{module_nam}/{class_binary_name}.class
//
// E.g.
//
// jar:file:///ws/tools/jigsaw/uberjar/build/apps/super-launcher.jar!/modules/com.lib/com/lib/Lib.class
//
public class SuperLauncher {
    public static void main(String args[]) throws Exception {
        String modulePath = args[0]; // E.g., "modules" would refer to the /modules directory in the JAR file that contains SuperLauncher.class
        String mainModule = args[1]; // E.g., "com.simple"
        String mainClass  = args[2]; // E.g., "com.simple.Simple"
        dolaunch(SuperLauncher.class, modulePath, mainModule, mainClass);
    }

    public static void dolaunch(Class callerClass, String modulesDir, String mainModule, String mainClass) throws Exception {
        URL locationURL = callerClass.getProtectionDomain().getCodeSource().getLocation();
        String jarPath =  locationURL.getPath();

        File jarFile = new File(jarPath);
        SuperJarModuleFinder mf = new SuperJarModuleFinder(jarFile, modulesDir);

        // Create a new Configuration for a new module layer deriving from the boot
        // configuration, and resolving the "com.simple" module.
        Configuration cfg = ModuleLayer.boot().configuration().resolve(mf, ModuleFinder.of(), Set.of(mainModule));
        ModuleLayer ml = ModuleLayer.boot().defineModulesWithOneLoader(cfg, SuperLauncher.class.getClassLoader());

        System.out.println(ml.configuration());
        Class<?> clazz = ml.findLoader(mainModule).loadClass(mainClass);

        java.lang.reflect.Method mth = clazz.getMethod("main", String[].class);
        mth.invoke(null,new Object[] {null});
    }
}

class SuperJarModuleFinder implements ModuleFinder {
    private final Map<String, ModuleReference> allModules = new HashMap<>();

    // Example: jarFile = "build/apps/super-launcher.jar", rootDir = "modules"
    public SuperJarModuleFinder(File jarFile, String rootDir) throws IOException {
        Map<String, String> env = new HashMap<>(); 
        // env.put("create", "true");

        // locate file system by using the syntax 
        // defined in java.net.JarURLConnection
        URI uri = URI.create("jar:file:" + jarFile.toString());
        FileSystem zipfs = FileSystems.newFileSystem(uri, env);
        Path rootPath = zipfs.getPath("/" + rootDir);
        System.out.println(rootPath);

        try (Stream<Path> stream = Files.list(rootPath)) {
            stream.filter(Files::isDirectory)
                .forEach(p -> addModule(p));
        }
    }

    void addModule(Path p) {
        try {
            Path moduleInfo = p.resolve("module-info.class");
            System.out.println("FOUND Module: " + moduleInfo);

            InputStream in = Files.newInputStream(moduleInfo);
            ModuleDescriptor moduleDescriptor = ModuleDescriptor.read(in);
            System.out.println("moduleDescriptor = " + moduleDescriptor);
            String moduleName = p.toString();
            moduleName = moduleName.substring(moduleName.lastIndexOf('/') + 1);
            allModules.put(moduleName, new SuperJarModuleReference(moduleDescriptor, p, p.toUri()));
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    @Override
    public Optional<ModuleReference> find(String name) {
        Objects.requireNonNull(name);

        ModuleReference m = allModules.get(name);
        System.out.println("SuperJarModuleFinder.find " + name + " = " + m);

        if (m != null) {
            return Optional.of(m);
        } else {
            return Optional.empty();
        }
    }

    @Override
    public Set<ModuleReference> findAll() {
        System.out.println("SuperJarModuleFinder.findAll");
        return allModules.values().stream().collect(Collectors.toSet());
    }
}

class SuperJarModuleReference extends ModuleReference {
    Path rootPath;

    /**
     * Constructs a new instance of this class.
     */
    public SuperJarModuleReference(ModuleDescriptor descriptor,
                                   Path rootPath,
                                   URI locationURI) {
        super(descriptor, Objects.requireNonNull(locationURI));
        System.out.println("SuperJarModuleReference @ " + locationURI);
        this.rootPath = rootPath;
    }

    @Override
    public ModuleReader open() throws IOException {
        System.out.println("SuperJarModuleReference.open @ " + rootPath);
        return new SuperJarModuleReader(rootPath);
    }
}

class SuperJarModuleReader implements ModuleReader {
    Path rootPath;
    SuperJarModuleReader(Path rootPath) {
        this.rootPath = rootPath;
    }

    /**
     * Finds a resource, returning a URI to the resource in the module.
     *
     * <p> If the module reader can determine that the name locates a directory
     * then the resulting URI will end with a slash ('/'). </p>
     *
     * @param  name
     *         The name of the resource to open for reading
     *
     * @return A URI to the resource; an empty {@code Optional} if the resource
     *         is not found or a URI cannot be constructed to locate the
     *         resource
     *
     * @throws IOException
     *         If an I/O error occurs or the module reader is closed
     * @throws SecurityException
     *         If denied by the security manager
     *
     * @see ClassLoader#getResource(String)
     */
    public Optional<URI> find(String name) throws IOException {
        URI uri = rootPath.resolve(name).toUri();
        if (uri != null) {
            return Optional.of(uri);
        } else {
            return Optional.empty();
        }
    }

    /**
     * Opens a resource, returning an input stream to read the resource in
     * the module.
     *
     * <p> The behavior of the input stream when used after the module reader
     * is closed is implementation specific and therefore not specified. </p>
     *
     * @param  name
     *         The name of the resource to open for reading
     *
     * @return An input stream to read the resource or an empty
     *         {@code Optional} if not found
     *
     * @throws IOException
     *         If an I/O error occurs or the module reader is closed
     * @throws SecurityException
     *         If denied by the security manager
     */
    public Optional<InputStream> open(String name) throws IOException {
        Path p = rootPath.resolve(name);
        System.out.println("SuperJarModuleReader.open " + name + " @ " + p.toUri());
        InputStream is = Files.newInputStream(p);
        if (is != null) {
            return Optional.of(is);
        } else {
            return Optional.empty();
        }
    }


    /**
     * Lists the contents of the module, returning a stream of elements that
     * are the names of all resources in the module. Whether the stream of
     * elements includes names corresponding to directories in the module is
     * module reader specific.
     *
     * <p> In lazy implementations then an {@code IOException} may be thrown
     * when using the stream to list the module contents. If this occurs then
     * the {@code IOException} will be wrapped in an {@link
     * java.io.UncheckedIOException} and thrown from the method that caused the
     * access to be attempted. {@code SecurityException} may also be thrown
     * when using the stream to list the module contents and access is denied
     * by the security manager. </p>
     *
     * <p> The behavior of the stream when used after the module reader is
     * closed is implementation specific and therefore not specified. </p>
     *
     * @return A stream of elements that are the names of all resources
     *         in the module
     *
     * @throws IOException
     *         If an I/O error occurs or the module reader is closed
     * @throws SecurityException
     *         If denied by the security manager
     */
    public Stream<String> list() throws IOException {
        // FIXME -- use FileSystem to walk everything under rootPath
        return null; // FIXME
    }

    public void close() {}
}