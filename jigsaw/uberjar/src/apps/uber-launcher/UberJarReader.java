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
import java.util.jar.*;
import java.util.zip.*;

public class UberJarReader {
    final static String JAR_NAME_SEPARATOR = "!/";
    final static String JAR_SUFFIX = ".jar";
    final static String CLASS_SUFFIX = ".class";
    final static String JAR_PROTOCOL = "ujar:file:";
    final static String FILE_PROTOCOL = "file:";

    static public void initialize() {
        URL.setURLStreamHandlerFactory(new UberJarURLStreamHandlerFactory());
    }

    // Example: location = "ujar:file:uberdemo.jar!/com.simple.jar"
    //          entry    = "com/simple/Main.class"
    public static byte[] read(String location, String entry) throws IOException {
        return getReader(location).read(entry);
    }

    public static InputStream open(String location, String entry) throws IOException {
        byte[] data = read(location, entry);
        if (data == null) {
            return null;
        } else {
            return new ByteArrayInputStream(data);
        }
    }

    // FIXME: Not the most efficient implementation!
    public static URL findResource(String location, String entry) {
        try {
            if (read(location, entry) != null) {
                return new URL(location + entry);
            }
        } catch (Exception e) {
            // FIXME: huh?
        }
        return null;
    }


    static boolean isEmbeddedJar(String source) {
        if (source.indexOf(JAR_PROTOCOL) < 0) {
            return false;
        }
        if (source.indexOf(JAR_NAME_SEPARATOR) < 0) {
            return false;
        }
        if (source.endsWith(CLASS_SUFFIX + JAR_NAME_SEPARATOR)) {
            return false;
        }
        if (source.length() - JAR_NAME_SEPARATOR.length() != source.lastIndexOf(JAR_NAME_SEPARATOR)) {
            return false;
        }
        if (isSimpleJarURL(source) || isJarProtocolWithDirectory(source)) {
            return false;
        }
        return true;
    }

    static WeakHashMap<String, AbstractJarReader> readerCache =
        new WeakHashMap<String, AbstractJarReader>();

    static AbstractJarReader getReader(String source)
        throws IOException, IllegalArgumentException, MalformedURLException {
        //System.out.println("source: " + source);
        AbstractJarReader r = readerCache.get(source);
        if (r != null) {
            // this means the source has already been checked, no need to check it again
            return r;
        }
        if (isEmbeddedJar(source)) {
            // assume source = "ujar:file:/some/path/outer.jar!/dir1/mid.jar!/dir2/inner.jar!/"
            //String parentURL = "ujar:file:/some/path/outer.jar!/dir1/mid.jar!/";
            //String myPath = "dir1/mid.jar";
            String[] urls = source.split("!");
            int endIndex = source.indexOf(urls[urls.length - 2]);
            String parentURL = source.substring(0, endIndex + 1);
            //System.out.println("parentURL: " + parentURL);
            String myPath = urls[urls.length - 2].substring(1);
            //System.out.println("myPath: " + myPath);
            AbstractJarReader parentReader = getReader(parentURL);
            //System.out.println("parentReader: " + parentReader);
            byte[] myBytes = parentReader.read(myPath);

            r = new EmbeddedJarReader(myBytes);
        } else {
            String u = source;
            URL url;
            if (isJarProtocolWithDirectory(source)) {
                // Remove the last '!' and end the url with '/'.
                // e.g source = "ujar:file:test.jar!/a/dir!/
                //     url = "ujar:file:test.jar!/a/dir/
                u = source.substring(0, source.lastIndexOf('!')) + "/";
            } else if (!isSimpleJarURL(source)) {
                throw new IllegalArgumentException("unsupported source: " + source);
            }

            if (u.startsWith("ujar:")) {
                u = u.substring(1);
            }
            url = new URL(u);
            r = new SimpleJarReader(url);
        }
        readerCache.put(source, r);
        return r;
    }

    static boolean isSimpleJarURL(final String source) {
        if (!source.endsWith(JAR_SUFFIX + JAR_NAME_SEPARATOR)) {
            return false;
        }
        int firstIndex = source.indexOf(JAR_NAME_SEPARATOR);
        return firstIndex >= 0 && firstIndex == source.lastIndexOf(JAR_NAME_SEPARATOR);
    }

    static boolean isSimpleJarFile(final String source) {
        return !source.startsWith(JAR_PROTOCOL) &&
               !source.startsWith(FILE_PROTOCOL) &&
               source.endsWith(JAR_SUFFIX);
    }

    static boolean isJarProtocolWithDirectory(final String source) {
        return source.startsWith(JAR_PROTOCOL) &&
               source.endsWith(JAR_NAME_SEPARATOR) &&
               !source.endsWith(JAR_SUFFIX + JAR_NAME_SEPARATOR) &&
               !source.endsWith(CLASS_SUFFIX + JAR_NAME_SEPARATOR);
    }

    abstract static class AbstractJarReader {
        abstract byte[] read(String name) throws IOException;
    }

    static class SimpleJarReader extends AbstractJarReader {
        URLClassLoader loader;
        HashMap<String, byte[]> entryCache;

        protected SimpleJarReader(URL url) throws MalformedURLException {
            loader = new URLClassLoader(new URL[]{url});
            this.entryCache =  new HashMap<String, byte[]>();
        }

        @Override
        byte[] read(String name) throws IOException {
            //System.out.println("SimpleJarReader.read name: " + name);
            String entryName = name;
            byte[] bytes = entryCache.get(entryName);
            if (bytes != null) {
                return bytes;
            } else {
                if (loader.findResource(entryName) != null) {
                    InputStream is = loader.getResourceAsStream(entryName);
                    bytes = new byte[is.available()];
                    is.read(bytes);
                    //System.out.println("Add SimpleJarReader: " + entryName + " " + bytes + " " + bytes.length);
                    entryCache.put(entryName, bytes);
                    return bytes;
                } else {
                    return null;
                }
            }
        }
    }

    static class EmbeddedJarReader extends AbstractJarReader {
        final static int BUFFER_SIZE = 4096;
        ZipInputStream zins;
        HashMap<String, byte[]> entryCache;

        protected EmbeddedJarReader(byte[] jarBytes) {
            this.zins = new ZipInputStream(new ByteArrayInputStream(jarBytes));
            this.entryCache =  new HashMap<String, byte[]>();
        }

        @Override
        byte[] read(String name) throws IOException {
            boolean found = false;
            byte[] bytes = entryCache.get(name);
            if (bytes != null) {
                return bytes;
            } else {
                ZipEntry ze = null;
                while ((ze = zins.getNextEntry()) != null) {
                    if (!ze.isDirectory()) {
                        bytes = readEntry(zins, ze);
                        String entryName = ze.getName();
                        //System.out.println("adding " + entryName);
                        entryCache.put(entryName, bytes);
                        if (entryName.equals(name)) {
                            //System.out.println("found " + name);
                            found = true;
                            break;
                        }
                    }
                }
            }

            return bytes;
        }

        private static byte[] readEntry(InputStream in, ZipEntry entry) throws IOException {
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            long size = entry.getSize();
            //System.out.println("in " + in + " entry " + entry + " size " + size);
            int nRead;
            byte[] data = new byte[BUFFER_SIZE];
            while ((nRead = in.read(data, 0, data.length)) != -1) {
                baos.write(data, 0, nRead);
            }
            baos.close();
            return baos.toByteArray();
        }
    }
}


class UberJarURLConnection extends URLConnection {
    protected UberJarURLConnection(URL url) {
        super(url);
        // FIXME: validate the url?
    }

    @Override
    public void connect() throws IOException {

    }

    public InputStream getInputStream() throws IOException {
        // Example: url_string = "ujar:file:build/uberdemo.jar!/modules/com.simple.jar!/com/simple/myresource.txt"
        // location = "ujar:file:build/uberdemo.jar!/modules/com.simple.jar!/";
        // name     = "com/simple/myresource.txt"
        String urlString = getURL().toString();
        int index = urlString.lastIndexOf("!/");
        String location = urlString.substring(0, index + 2);
        String name = urlString.substring(index + 2);
        return UberJarReader.open(location, name);
    }
}


class UberJarURLStreamHandler extends URLStreamHandler {
    @Override
    protected URLConnection openConnection(URL url) throws IOException {
        return new UberJarURLConnection(url);
    }
}

class UberJarURLStreamHandlerFactory implements URLStreamHandlerFactory {
    @Override
    public URLStreamHandler createURLStreamHandler(String protocol) {
        if ("ujar".equals(protocol)) {
            return new UberJarURLStreamHandler();
        }

        return null;
    }
}