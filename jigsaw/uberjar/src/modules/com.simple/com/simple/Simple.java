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

package com.simple;

import java.lang.reflect.Method;
import java.util.*;
import java.util.stream.*;
import java.io.*;
import java.net.*;

public class Simple {
    public static void main(String[] args) throws Exception {
        System.out.println("Hello World!");
        System.out.println("Loader = " + Simple.class.getClassLoader());
        System.out.println("Module = " + Simple.class.getModule());

        ModuleLayer layer = Simple.class.getModule().getLayer();
        int h = (layer == null) ? 0 : layer.hashCode();
        System.out.println("My ModuleLayer = @" + h + " << " + layer + " >>");

        if (layer != null) {
            List<ModuleLayer> parents = layer.parents();
            System.out.println("My parent ModuleLayer = << " + parents + " >>");
        }

        System.out.println(new Foo()); // try to load another class
        System.out.println(Foo.class.getClassLoader());

        String resname = "/com/simple/myresource.txt";
        URL url = Simple.class.getResource(resname);
        System.out.println("Resource URL = " + url);
        InputStream in = Simple.class.getResourceAsStream(resname);
        System.out.println("Resource InputStream = " + in);
        if (in != null) {
            String text = new BufferedReader(new InputStreamReader(in))
                .lines()
                .collect(Collectors.joining("\n"));
            System.out.println(text);
        }
    }

    static class Foo {}
}
