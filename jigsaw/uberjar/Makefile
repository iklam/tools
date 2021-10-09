#
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved.
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
#
# This code is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 2 only, as
# published by the Free Software Foundation.
#
# This code is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# version 2 for more details (a copy is included in the LICENSE file that
# accompanied this code).
#
# You should have received a copy of the GNU General Public License version
# 2 along with this work; if not, write to the Free Software Foundation,
# Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
# or visit www.oracle.com if you need additional information or have any
# questions.
#

ifneq (${TESTBED},)
JAVA_HOME = ${TESTBED}
endif

JAVA  = ${JAVA_HOME}/bin/java
JAVAC = ${JAVA_HOME}/bin/javac
JAR   = ${JAVA_HOME}/bin/jar


# build/modules --- these are Jigsaw modules, and can be executed using "java --module-path ..."
# build/apps    --- these are plain-old JAR files. They are executed like "java -cp build/apps/path-launcher.jar ..."
#
BUILD_DIR = build
MODULES_DIR = build/modules
APPS_DIR    = build/apps
TMP_CLASSES = build/tmpclasses

# com.simple  -- A simple module that has no dependency on other modules
SIMPLE_MODULE      = ${MODULES_DIR}/com.simple.jar
SIMPLE_DIR         = src/modules/com.simple
SIMPLE_MODULE_SRC  = $(wildcard ${SIMPLE_DIR}/com/simple/*.java ${SIMPLE_DIR}/module-info.java)
SIMPLE_MODULE_RES  = $(wildcard ${SIMPLE_DIR}/com/simple/*.txt)

# com.lib     -- A "library" module that exports a simple API
LIB_MODULE         = ${MODULES_DIR}/com.lib.jar
LIB_DIR            = src/modules/com.lib
LIB_MODULE_SRC     = $(wildcard ${LIB_DIR}/com/lib/*.java ${LIB_DIR}/module-info.java)
LIB_MODULE_RES     = $(wildcard ${LIB_DIR}/com/lib/*.txt)

# com.complex -- A "commplex" module that depends on the com.lib module
COMPLEX_MODULE     = ${MODULES_DIR}/com.complex.jar
COMPLEX_DIR        = src/modules/com.complex
COMPLEX_MODULE_SRC = $(wildcard ${COMPLEX_DIR}/com/complex/*.java ${COMPLEX_DIR}/module-info.java)
COMPLEX_MODULE_RES = $(wildcard ${COMPLEX_DIR}/com/complex/*.txt)

# This is a demo of how to create your own ModuleLayer for loading modules
# outside of the --module-path
PATH_LAUNCHER      = ${APPS_DIR}/path-launcher.jar
PATH_LAUNCHER_SRC  = $(wildcard src/apps/path-launcher/*.java)
PATH_LAUNCHER_MAIN = pathlauncher.PathLauncher

# This is a demo of how to load modules embedded inside an uber jar file.
UBER_LAUNCHER      = ${APPS_DIR}/uber-launcher.jar
UBER_LAUNCHER_SRC  = $(wildcard src/apps/uber-launcher/*.java)
UBER_LAUNCHER_MAIN = demo.UberLauncher


ALL_MODULES = ${SIMPLE_MODULE} ${LIB_MODULE} ${COMPLEX_MODULE}

all: ${ALL_MODULES} ${PATH_LAUNCHER} ${UBER_LAUNCHER}

${SIMPLE_MODULE}: ${SIMPLE_MODULE_SRC} ${SIMPLE_MODULE_RES}
	rm -rf ${TMP_CLASSES}
	mkdir -p ${TMP_CLASSES}
	${JAVAC} -d ${TMP_CLASSES} ${SIMPLE_MODULE_SRC}
	cp ${SIMPLE_MODULE_RES} ${TMP_CLASSES}/com/simple
	mkdir -p `dirname $@`
	${JAR} cvf $@ -C ${TMP_CLASSES} .

${LIB_MODULE}: ${LIB_MODULE_SRC} ${LIB_MODULE_RES}
	rm -rf ${TMP_CLASSES}
	mkdir -p ${TMP_CLASSES}
	${JAVAC} -d ${TMP_CLASSES} ${LIB_MODULE_SRC}
	cp ${LIB_MODULE_RES} ${TMP_CLASSES}/com/lib
	mkdir -p `dirname $@`
	${JAR} cvf $@ -C ${TMP_CLASSES} .

${COMPLEX_MODULE}: ${COMPLEX_MODULE_SRC} ${COMPLEX_MODULE_RES}  ${LIB_MODULE}
	rm -rf ${TMP_CLASSES}
	mkdir -p ${TMP_CLASSES}
	${JAVAC} -d ${TMP_CLASSES} --module-path ${MODULES_DIR} ${COMPLEX_MODULE_SRC}
	cp ${COMPLEX_MODULE_RES} ${TMP_CLASSES}/com/complex
	mkdir -p `dirname $@`
	${JAR} cvf $@ -C ${TMP_CLASSES} .

${PATH_LAUNCHER}: ${PATH_LAUNCHER_SRC}
	rm -rf ${TMP_CLASSES}
	mkdir -p ${TMP_CLASSES}
	${JAVAC} -d ${TMP_CLASSES} ${PATH_LAUNCHER_SRC}
	mkdir -p `dirname $@`
	${JAR} cvf $@ -C ${TMP_CLASSES} .

${UBER_LAUNCHER}: ${UBER_LAUNCHER_SRC} ${ALL_MODULES}
	rm -rf ${TMP_CLASSES}
	mkdir -p ${TMP_CLASSES}
	${JAVAC} -d ${TMP_CLASSES} ${UBER_LAUNCHER_SRC}
	mkdir -p `dirname $@`
	${JAR} cvf $@ -C ${TMP_CLASSES} . -C ${BUILD_DIR} modules

#==============================
# Traditional way of running Jigsaw modular apps using "java --module-path"
r0 run-simple: ${SIMPLE_MODULE}
	${JAVA} --module-path=${MODULES_DIR} -m com.simple/com.simple.Simple

r1 run-complex: ${COMPLEX_MODULE}
	${JAVA} --module-path=${MODULES_DIR} -m com.complex/com.complex.Complex

#==============================
# Run the test apps as modules that are loaded *outside* of --module-path
# -- PathLaucher loads these modules from the specified file system path
r2 run-simple-with-path-launcher: ${PATH_LAUNCHER} ${ALL_MODULES}
	${JAVA} -cp ${PATH_LAUNCHER} ${PATH_LAUNCHER_MAIN} ${MODULES_DIR} com.simple com.simple.Simple

r3 run-complex-with-path-launcher: ${PATH_LAUNCHER} ${ALL_MODULES}
	${JAVA} -cp ${PATH_LAUNCHER} ${PATH_LAUNCHER_MAIN} ${MODULES_DIR} com.complex com.complex.Complex

#==============================
# This is a demo of using the "ujar:" URL to access classes/resources that are embedded
# inside an uber JAR file. E.g.,
#   ujar:file:build/apps/uber-launcher.jar!/modules/com.simple.jar!/com/simple/Simple.class
#   ujar:file:build/apps/uber-launcher.jar!/modules/com.simple.jar!/com/simple/myresource.txt
r4 run-uber-jar-reader-demo: ${UBER_LAUNCHER}
	${JAVA} -cp ${UBER_LAUNCHER} demo.UberJarReaderDemo ${UBER_LAUNCHER}

#==============================
# Quick-and-dirty demo of loading modules JAR entries embedded in an uber-jar file. In this
# example, the uber-jar looks like this:
#
# demo/UberLauncher.class
# demo/UberJarReaderDemo
# demo/Utils.class ...
# modules/com.complex.jar
# modules/com.lib.jar
# modules/com.simple.jar
#
# The UberLauncher class is used to load modules embedded in the "/modules/" directory and
# execute their main classes.
r5 run-simple-with-uber-launcher: ${UBER_LAUNCHER} ${ALL_MODULES}
	${JAVA} -cp ${UBER_LAUNCHER} ${UBER_LAUNCHER_MAIN} modules com.simple com.simple.Simple

r6 run-complex-with-uber-launcher: ${UBER_LAUNCHER} ${ALL_MODULES}
	${JAVA} -cp ${UBER_LAUNCHER} ${UBER_LAUNCHER_MAIN} modules com.complex com.complex.Complex

clean:
	rm -rf build
