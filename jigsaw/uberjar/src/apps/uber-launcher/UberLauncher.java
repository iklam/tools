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

public class UberLauncher {
    public static void main(String args[]) throws Exception {
        String modulePath = args[0]; // E.g., "modules" would refer to the /modules directory in the JAR file that contains UberLauncher.class
        String mainModule = args[1]; // E.g., "com.simple"
        String mainClass  = args[2]; // E.g., "com.simple.Simple"
        dolaunch(UberLauncher.class, modulePath, mainModule, mainClass);
    }


    public static void dolaunch(Class callerClass, String modulesDir, String mainModule, String mainClass) throws Exception {
        UberJarReader.initialize();
        URL locationURL = callerClass.getProtectionDomain().getCodeSource().getLocation();
        String jarPath =  locationURL.getPath();

        File jarFile = new File(jarPath);
        UberJarModuleFinder mf = new UberJarModuleFinder(jarFile, modulesDir);

        // Create a new Configuration for a new module layer deriving from the boot
        // configuration, and resolving the "com.simple" module.
        Configuration cfg = ModuleLayer.boot().configuration().resolve(mf, ModuleFinder.of(), Set.of(mainModule));
        ModuleLayer ml = ModuleLayer.boot().defineModulesWithOneLoader(cfg, UberLauncher.class.getClassLoader());

        System.out.println(ml.configuration());
        Class<?> clazz = ml.findLoader(mainModule).loadClass(mainClass);

        java.lang.reflect.Method mth = clazz.getMethod("main", String[].class);
        mth.invoke(null,new Object[] {null});
    }



    public static void oldmain(String args[]) throws Exception {
        System.out.println(UberLauncher.class.getProtectionDomain().getCodeSource());

        UberJarReader.initialize();
        File jarFile = new File("build/uberdemo.jar");
        UberJarModuleFinder mf = new UberJarModuleFinder(jarFile, "modules");

        // Create a new Configuration for a new module layer deriving from the boot
        // configuration, and resolving the "com.simple" module.
        Configuration cfg = ModuleLayer.boot().configuration().resolve(mf, ModuleFinder.of(), Set.of("com.simple"));

        ModuleLayer ml = ModuleLayer.boot().defineModulesWithOneLoader(cfg, UberLauncher.class.getClassLoader());

        System.out.println(ml.configuration());
        Class<?> clazz = ml.findLoader("com.simple").loadClass("com.simple.Main");

        java.lang.reflect.Method mth = clazz.getMethod("main", String[].class);
        mth.invoke(null,new Object[] {null});
    }
}

class UberJarModuleFinder implements ModuleFinder {
    private final Map<String, ModuleReference> allModules = new HashMap<>();

    // Example: jarFile = "build/uberdemo.jar", rootDir = "modules"
    public UberJarModuleFinder(File jarFile, String rootDir) throws IOException {
        ZipInputStream zins;
        try {
            zins = new ZipInputStream(new FileInputStream(jarFile));
        } catch (Throwable t) {
            System.out.println("Unexpected : " + t);
            t.printStackTrace();
            System.out.println("Must be a valid JAR file: " + jarFile);
            throw new RuntimeException(t);
        }

        ZipEntry ze = null;
        if (!rootDir.endsWith("/")) {
            rootDir += "/";
        }
        int prefixLen = rootDir.length();

        while ((ze = zins.getNextEntry()) != null) {
            if (!ze.isDirectory()) {
                String entryName = ze.getName();

                if (entryName.startsWith(rootDir) && entryName.endsWith(".jar") &&
                    entryName.indexOf('/', prefixLen) < 0) {
                    String moduleName = entryName.substring(prefixLen); // skip prefix
                    moduleName = moduleName.substring(0, moduleName.length() - 4); // trim trailing ".jar"
                    try {
                        String location = "ujar:file:" + jarFile + "!/" + entryName + "!/";
                        System.out.println("FOUND Module: " + moduleName + " @ " + location);
                        InputStream in = UberJarReader.open(location, "module-info.class");
                        if (in != null) {
                            ModuleDescriptor moduleDescriptor = ModuleDescriptor.read(in);
                            System.out.println("moduleDescriptor = " + moduleDescriptor);
                            allModules.put(moduleName, new UberJarModuleReference(moduleDescriptor, location, new URI(location)));
                        }
                    } catch (URISyntaxException e) {
                        e.printStackTrace();
                        throw new Error("Cannot happen", e);
                    }
                }
            }
        }
    }

    @Override
    public Optional<ModuleReference> find(String name) {
        Objects.requireNonNull(name);

        System.out.println("UberJarModuleFinder.find " + name);

        ModuleReference m = allModules.get(name);
        if (m != null) {
            return Optional.of(m);
        } else {
            return Optional.empty();
        }
    }

    @Override
    public Set<ModuleReference> findAll() {
        System.out.println("UberJarModuleFinder.findAll");
        return allModules.values().stream().collect(Collectors.toSet());
    }
}

class UberJarModuleReference extends ModuleReference {
    String locationString;

    /**
     * Constructs a new instance of this class.
     */
    public UberJarModuleReference(ModuleDescriptor descriptor,
                                  String locationString,
                                  URI locationURI) {
        super(descriptor, Objects.requireNonNull(locationURI));
        this.locationString = locationString;
    }

    @Override
    public ModuleReader open() throws IOException {
        System.out.println("UberJarModuleReference.open @ " + locationString);
        return new UberJarModuleReader(locationString);
    }
}

class UberJarModuleReader implements ModuleReader {
    String locationString;
    UberJarModuleReader(String locationString) {
        this.locationString = locationString;
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
        URL url = UberJarReader.findResource(locationString, name);
        try {
            if (url != null) {
                return Optional.of(new URI(url.toString()));
            }
        } catch (Exception e) {
            Utils.unexpected(e);
        }
        return Optional.empty();
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
        System.out.println("UberJarModuleReader.open @ " + locationString + " :: " + name);
        InputStream is = UberJarReader.open(locationString, name);
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
        // FIXME
        return null; // FIXME
    }

    public void close() {}
}