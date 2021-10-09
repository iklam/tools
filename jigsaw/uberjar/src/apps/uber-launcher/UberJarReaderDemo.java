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
import java.net.*;
import java.util.*;

public class UberJarReaderDemo {
    public static void main(String args[]) throws Exception {
        String jarFile = args[0]; // Example: "build/apps/uber-launcher.jar"

        System.out.println("Loading com.simple from Uber JAR location, without using modules");

        UberJarReader.initialize();

        String location = "ujar:file:" + jarFile + "!/modules/com.simple.jar!/";
        System.out.println("location = " + location);

        // First try to read the bytes using the UberJarReader API:
        byte[] data = UberJarReader.read(location, "com/simple/Simple.class");
        System.out.println("data = " + data);
        if (data != null) {
            System.out.println("data.length = " + data.length);
        }

        MyClassLoader loader = new MyClassLoader(UberJarReaderDemo.class.getClassLoader(), location);
        Class<?> clazz = loader.loadClass("com.simple.Simple");

        java.lang.reflect.Method mth = clazz.getMethod("main", String[].class);
        mth.invoke(null,new Object[] {null});
    }

    static class MyClassLoader extends URLClassLoader {
        String location;
        ClassLoader parent;

        MyClassLoader(ClassLoader parent, String location) {
            super(new URL[0]);
            this.location = location;
            this.parent = parent;
        }

        protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
            // System.out.println("Trying to load: " + location + " --> " + name);
            synchronized (getClassLoadingLock(name)) {
                Class<?> c = findLoadedClass(name);
                if (c == null) {
                    try {
                        c = findClass(name);
                    } catch (ClassNotFoundException e) {}
                }
                if (c == null) {
                    try {
                        c = getParent().loadClass(name);
                    } catch (ClassNotFoundException e2) {}
                }
                if (c  == null) {
                    try {
                        byte[] data = UberJarReader.read(location, name.replace('.', '/') + ".class");
                        if (data != null) {
                            c = defineClass(name, data, 0, data.length);
                        }
                    } catch (IOException e) {}
                }
                if (c == null) {
                    throw new ClassNotFoundException(name);
                }

                if (resolve) {
                    resolveClass(c);
                }
                return c;
            }
        }

        public URL findResource(String name) {
            System.out.println("MyClassLoader.findResource: " + name);
            Objects.requireNonNull(name);
            return UberJarReader.findResource(location, name);
        }
    }
}
