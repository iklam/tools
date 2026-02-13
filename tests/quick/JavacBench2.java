/*

Build:

rm -rf tmpclasses
mkdir tmpclasses
javac -d tmpclasses  JavacBench2.java
jar c0f   JavacBench2.jar -C tmpclasses .


===============================================================================
[1] Baseline - no AOT

$ java -cp JavacBench2.jar JavacBench2 100 50

Compiled 100 files 50 times in 5341 ms
  0 = 58.866 ms  1.699 files per ms
  1 = 23.332 ms  4.286 files per ms
  2 = 18.054 ms  5.539 files per ms
  3 = 16.153 ms  6.191 files per ms
  4 = 13.880 ms  7.205 files per ms
  5 = 11.327 ms  8.829 files per ms
  6 = 10.542 ms  9.486 files per ms
  7 = 10.211 ms  9.793 files per ms
  8 = 10.041 ms  9.959 files per ms
  9 = 11.341 ms  8.818 files per ms
 10 = 13.339 ms  7.497 files per ms
 11 =  9.300 ms 10.753 files per ms
 12 =  9.465 ms 10.565 files per ms
 13 =  9.335 ms 10.713 files per ms
 14 =  9.010 ms 11.099 files per ms
 15 =  9.165 ms 10.911 files per ms
 16 =  9.212 ms 10.856 files per ms
 17 = 10.262 ms  9.745 files per ms
 18 =  9.049 ms 11.051 files per ms
 19 =  8.814 ms 11.346 files per ms
 20 =  8.571 ms 11.667 files per ms
 21 =  8.802 ms 11.361 files per ms
 22 =  8.455 ms 11.827 files per ms
 23 =  8.882 ms 11.258 files per ms
 24 =  8.516 ms 11.742 files per ms
 25 =  8.633 ms 11.583 files per ms
 26 =  8.645 ms 11.568 files per ms
 27 =  8.453 ms 11.830 files per ms
 28 =  8.333 ms 12.001 files per ms
 29 =  9.532 ms 10.491 files per ms
 30 =  9.055 ms 11.043 files per ms
 31 =  8.586 ms 11.646 files per ms
 32 =  8.411 ms 11.890 files per ms
 33 =  8.300 ms 12.049 files per ms
 34 =  8.176 ms 12.231 files per ms
 35 =  8.224 ms 12.159 files per ms
 36 =  8.424 ms 11.870 files per ms
 37 =  8.230 ms 12.151 files per ms
 38 =  8.133 ms 12.296 files per ms
 39 =  8.104 ms 12.340 files per ms
 40 =  8.208 ms 12.183 files per ms
 41 =  8.039 ms 12.440 files per ms
 42 =  8.523 ms 11.733 files per ms
 43 =  8.266 ms 12.097 files per ms
 44 =  7.831 ms 12.770 files per ms
 45 =  7.946 ms 12.586 files per ms
 46 =  7.881 ms 12.689 files per ms
 47 =  7.895 ms 12.666 files per ms
 48 =  7.868 ms 12.709 files per ms
 49 =  8.417 ms 11.880 files per ms

===============================================================================
[2] Short training

$ java -cp JavacBench2.jar -XX:AOTCacheOutput=jb2.aot JavacBench2 100 10
Compiled 100 files 10 times in 1963 ms
  0 = 60.648 ms  1.649 files per ms
  1 = 24.478 ms  4.085 files per ms
  2 = 19.323 ms  5.175 files per ms
  3 = 16.101 ms  6.211 files per ms
  4 = 16.030 ms  6.238 files per ms
  5 = 14.265 ms  7.010 files per ms
  6 = 10.472 ms  9.549 files per ms
  7 = 10.082 ms  9.919 files per ms
  8 =  9.981 ms 10.019 files per ms
  9 =  9.758 ms 10.248 files per ms
[...]
AOTCache creation is complete: jb2.aot 72089600 bytes
Removed temporary AOT configuration file jb2.aot.config

$ java -cp JavacBench2.jar -XX:AOTMode=on -XX:AOTCache=jb2.aot JavacBench2 100 50
Compiled 100 files 50 times in 6501 ms
  0 = 23.355 ms  4.282 files per ms
  1 = 16.748 ms  5.971 files per ms
  2 = 15.483 ms  6.459 files per ms
  3 = 15.425 ms  6.483 files per ms
  4 = 13.549 ms  7.381 files per ms
  5 = 12.846 ms  7.784 files per ms
  6 = 12.689 ms  7.881 files per ms
  7 = 13.011 ms  7.686 files per ms
  8 = 14.846 ms  6.736 files per ms
  9 = 12.759 ms  7.837 files per ms
 10 = 12.903 ms  7.750 files per ms
 11 = 13.058 ms  7.658 files per ms
 12 = 12.943 ms  7.726 files per ms
 13 = 13.422 ms  7.451 files per ms
 14 = 13.147 ms  7.606 files per ms
 15 = 12.308 ms  8.125 files per ms
 16 = 12.293 ms  8.135 files per ms
 17 = 12.427 ms  8.047 files per ms
 18 = 12.476 ms  8.016 files per ms
 19 = 12.894 ms  7.756 files per ms
 20 = 12.375 ms  8.081 files per ms
 21 = 12.458 ms  8.027 files per ms
 22 = 12.144 ms  8.234 files per ms
 23 = 12.311 ms  8.123 files per ms
 24 = 12.140 ms  8.237 files per ms
 25 = 12.714 ms  7.865 files per ms
 26 = 12.396 ms  8.067 files per ms
 27 = 12.549 ms  7.969 files per ms
 28 = 12.388 ms  8.073 files per ms
 29 = 12.466 ms  8.022 files per ms
 30 = 12.607 ms  7.932 files per ms
 31 = 12.248 ms  8.165 files per ms
 32 = 12.164 ms  8.221 files per ms
 33 = 12.352 ms  8.096 files per ms
 34 = 12.057 ms  8.294 files per ms
 35 = 12.316 ms  8.119 files per ms
 36 = 12.381 ms  8.077 files per ms
 37 = 12.321 ms  8.116 files per ms
 38 = 12.008 ms  8.328 files per ms
 39 = 12.112 ms  8.256 files per ms
 40 = 12.414 ms  8.055 files per ms
 41 = 12.822 ms  7.799 files per ms
 42 = 12.419 ms  8.052 files per ms
 43 = 12.373 ms  8.082 files per ms
 44 = 12.250 ms  8.163 files per ms
 45 = 12.458 ms  8.027 files per ms
 46 = 11.999 ms  8.334 files per ms
 47 = 12.582 ms  7.948 files per ms
 48 = 11.998 ms  8.335 files per ms
 49 = 12.289 ms  8.138 files per ms


===============================================================================
[3] Long training

$ java -cp JavacBench2.jar -XX:AOTCacheOutput=jb2.aot JavacBench2 100 50
Compiled 100 files 50 times in 5390 ms
  0 = 60.865 ms  1.643 files per ms
  1 = 23.706 ms  4.218 files per ms
  2 = 19.172 ms  5.216 files per ms
  3 = 16.505 ms  6.059 files per ms
  4 = 15.569 ms  6.423 files per ms
  5 = 14.503 ms  6.895 files per ms
  6 = 10.731 ms  9.319 files per ms
  7 = 10.534 ms  9.493 files per ms
  8 = 10.156 ms  9.846 files per ms
  9 =  9.845 ms 10.157 files per ms
 10 =  9.559 ms 10.462 files per ms
 11 =  9.416 ms 10.621 files per ms
 12 =  9.878 ms 10.123 files per ms
 13 =  9.334 ms 10.713 files per ms
 14 =  9.049 ms 11.051 files per ms
 15 =  9.018 ms 11.088 files per ms
 16 =  9.103 ms 10.985 files per ms
 17 =  9.204 ms 10.864 files per ms
 18 =  9.299 ms 10.754 files per ms
 19 =  8.834 ms 11.320 files per ms
 20 =  8.822 ms 11.335 files per ms
 21 =  8.810 ms 11.351 files per ms
 22 =  8.709 ms 11.482 files per ms
 23 =  8.691 ms 11.506 files per ms
 24 =  8.952 ms 11.170 files per ms
 25 =  8.698 ms 11.497 files per ms
 26 =  8.628 ms 11.590 files per ms
 27 =  8.456 ms 11.826 files per ms
 28 =  8.535 ms 11.716 files per ms
 29 =  8.555 ms 11.688 files per ms
 30 =  8.454 ms 11.829 files per ms
 31 =  8.713 ms 11.477 files per ms
 32 =  8.585 ms 11.648 files per ms
 33 =  8.345 ms 11.984 files per ms
 34 =  8.161 ms 12.254 files per ms
 35 =  8.071 ms 12.391 files per ms
 36 =  7.996 ms 12.507 files per ms
 37 =  8.735 ms 11.448 files per ms
 38 =  8.079 ms 12.377 files per ms
 39 =  8.051 ms 12.421 files per ms
 40 =  8.144 ms 12.279 files per ms
 41 =  8.123 ms 12.310 files per ms
 42 =  7.945 ms 12.586 files per ms
 43 =  8.217 ms 12.170 files per ms
 44 =  8.449 ms 11.835 files per ms
 45 =  7.931 ms 12.609 files per ms
 46 =  8.147 ms 12.274 files per ms
 47 =  8.048 ms 12.425 files per ms
 48 =  7.888 ms 12.677 files per ms
 49 =  7.876 ms 12.697 files per ms
[...]
AOTCache creation is complete: jb2.aot 82984960 bytes
Removed temporary AOT configuration file jb2.aot.config

$ java -cp JavacBench2.jar -XX:AOTMode=on -XX:AOTCache=jb2.aot JavacBench2 100 50
Compiled 100 files 50 times in 6252 ms
  0 = 21.820 ms  4.583 files per ms
  1 = 15.950 ms  6.270 files per ms
  2 = 15.021 ms  6.657 files per ms
  3 = 15.098 ms  6.623 files per ms
  4 = 13.278 ms  7.531 files per ms
  5 = 12.523 ms  7.985 files per ms
  6 = 12.552 ms  7.967 files per ms
  7 = 12.512 ms  7.992 files per ms
  8 = 14.432 ms  6.929 files per ms
  9 = 12.206 ms  8.192 files per ms
 10 = 12.320 ms  8.117 files per ms
 11 = 12.163 ms  8.221 files per ms
 12 = 12.168 ms  8.219 files per ms
 13 = 12.787 ms  7.820 files per ms
 14 = 12.909 ms  7.747 files per ms
 15 = 12.036 ms  8.308 files per ms
 16 = 11.790 ms  8.481 files per ms
 17 = 11.935 ms  8.379 files per ms
 18 = 12.133 ms  8.242 files per ms
 19 = 12.306 ms  8.126 files per ms
 20 = 11.813 ms  8.465 files per ms
 21 = 11.942 ms  8.374 files per ms
 22 = 11.885 ms  8.414 files per ms
 23 = 11.926 ms  8.385 files per ms
 24 = 11.837 ms  8.448 files per ms
 25 = 12.107 ms  8.260 files per ms
 26 = 11.932 ms  8.381 files per ms
 27 = 11.828 ms  8.455 files per ms
 28 = 11.782 ms  8.487 files per ms
 29 = 11.663 ms  8.574 files per ms
 30 = 12.232 ms  8.175 files per ms
 31 = 11.874 ms  8.422 files per ms
 32 = 11.942 ms  8.374 files per ms
 33 = 11.769 ms  8.497 files per ms
 34 = 11.676 ms  8.565 files per ms
 35 = 11.613 ms  8.611 files per ms
 36 = 12.117 ms  8.253 files per ms
 37 = 11.761 ms  8.503 files per ms
 38 = 11.877 ms  8.419 files per ms
 39 = 11.905 ms  8.400 files per ms
 40 = 11.758 ms  8.505 files per ms
 41 = 12.204 ms  8.194 files per ms
 42 = 11.717 ms  8.535 files per ms
 43 = 11.689 ms  8.555 files per ms
 44 = 11.665 ms  8.573 files per ms
 45 = 11.839 ms  8.447 files per ms
 46 = 11.861 ms  8.431 files per ms
 47 = 12.008 ms  8.327 files per ms
 48 = 11.804 ms  8.472 files per ms
 49 = 11.790 ms  8.482 files per ms

*/



import java.lang.invoke.MethodHandles;
import java.lang.management.ManagementFactory;
import java.lang.management.RuntimeMXBean;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;
import javax.tools.Diagnostic;
import javax.tools.DiagnosticCollector;
import javax.tools.FileObject;
import javax.tools.ForwardingJavaFileManager;
import javax.tools.JavaCompiler;
import javax.tools.JavaFileManager;
import javax.tools.JavaFileObject;
import javax.tools.SimpleJavaFileObject;
import javax.tools.ToolProvider;

/**
 * This program tries to compile a large number of classes that exercise a fair amount of
 * features in javac.
 */
public class JavacBench2 {
    static class ClassFile extends SimpleJavaFileObject {
        private final ByteArrayOutputStream baos = new ByteArrayOutputStream();
        protected ClassFile(String name) {
            super(URI.create("memo:///" + name.replace('.', '/') + Kind.CLASS.extension), Kind.CLASS);
        }
        @Override
        public ByteArrayOutputStream openOutputStream() {
            return this.baos;
        }
        byte[] toByteArray() {
            return baos.toByteArray();
        }
    }

    static class FileManager extends ForwardingJavaFileManager<JavaFileManager> {
        private Map<String, ClassFile> classesMap = new HashMap<String, ClassFile>();
        protected FileManager(JavaFileManager fileManager) {
            super(fileManager);
        }
        @Override
        public ClassFile getJavaFileForOutput(Location location, String name, JavaFileObject.Kind kind, FileObject source) {
            ClassFile classFile = new ClassFile(name);
            classesMap.put(name, classFile);
            return classFile;
        }
        public Map<String, byte[]> getCompiledClasses() {
            Map<String, byte[]> result = new HashMap<>();
            for (Map.Entry<String, ClassFile> entry : classesMap.entrySet()) {
                result.put(entry.getKey(), entry.getValue().toByteArray());
            }
            return result;
        }
    }

    static class SourceFile extends SimpleJavaFileObject {
        private CharSequence sourceCode;
        public SourceFile(String name, CharSequence sourceCode) {
            super(URI.create("memo:///" + name.replace('.', '/') + Kind.SOURCE.extension), Kind.SOURCE);
            this.sourceCode = sourceCode;
        }
        @Override
        public CharSequence getCharContent(boolean ignore) {
            return this.sourceCode;
        }
    }

    public Map<String, byte[]> compile() {
        JavaCompiler compiler = ToolProvider.getSystemJavaCompiler();
        DiagnosticCollector<JavaFileObject> ds = new DiagnosticCollector<>();
        Collection<SourceFile> sourceFiles = sources;

        try (FileManager fileManager = new FileManager(compiler.getStandardFileManager(ds, null, null))) {
            JavaCompiler.CompilationTask task = compiler.getTask(null, fileManager, null, null, null, sourceFiles);
            if (task.call()) {
                return fileManager.getCompiledClasses();
            } else {
                for (Diagnostic<? extends JavaFileObject> d : ds.getDiagnostics()) {
                    System.out.format("Line: %d, %s in %s", d.getLineNumber(), d.getMessage(null), d.getSource().getName());
                }
                throw new InternalError("compilation failure");
            }
        } catch (IOException e) {
            throw new InternalError(e);
        }
    }

    List<SourceFile> sources;

    static final String imports = """
        import java.lang.*;
        import java.util.*;
        """;

    static final String testClassBody = """
        // Some comments
        static long x;
        static final long y;
        static {
            y = System.currentTimeMillis();
        }
        /* More comments */
        @Deprecated
        String func() { return "String " + this + y; }
        public static void main(String args[]) {
            try {
                x = Long.parseLong(args[0]);
            } catch (Throwable t) {
                t.printStackTrace();
            }
            doit(() -> {
                System.out.println("Hello Lambda");
                Thread.dumpStack();
            });
        }
        static List<String> list = List.of("1", "2");
        class InnerClass1 {
            static final long yy = y;
        }
        static void doit(Runnable r) {
            for (var x : list) {
                r.run();
            }
        }
        static String patternMatch(String arg, Object o) {
            if (o instanceof String s) {
                return "1234";
            }
            final String b = "B";
            return switch (arg) {
                case "A" -> "a";
                case b   -> "b";
                default  -> "c";
            };
        }
        public sealed class SealedInnerClass {}
        public final class Foo extends SealedInnerClass {}
        enum Expression {
            ADDITION,
            SUBTRACTION,
            MULTIPLICATION,
            DIVISION
        }
        public record Point(int x, int y) {
            public Point(int x) {
                this(x, 0);
            }
        }
        """;

    String sanitySource = """
        public class Sanity implements java.util.concurrent.Callable<String> {
            public String call() {
                return "this is a test";
            }
        }
        """;

    void setup(int count) {
        sources = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            String source = imports + "public class Test" + i + " {" + testClassBody + "}";
            sources.add(new SourceFile("Test" + i, source));
        }

        sources.add(new SourceFile("Sanity", sanitySource));
    }

    public static void main(String args[]) throws Throwable {
        long mainStart = System.currentTimeMillis();
        RuntimeMXBean runtimeMXBean = ManagementFactory.getRuntimeMXBean();
        long vmStart = runtimeMXBean.getStartTime();
        long maxBeanOverHead = System.currentTimeMillis() - mainStart;

        // How many source files to compile in each loop iteration
        int files = 0;
        if (args.length > 0) {
            files = Integer.parseInt(args[0]);
        }

        // How many loops to run the benchmark
        int loops = 1;
        if (args.length > 1) {
            loops = Integer.parseInt(args[1]);
        }

        boolean sleep = false;
        if (args.length > 2 && args[2].equals("sleep")) {
            sleep = true;
        }

        long[] elapsed = new long[loops];

        run(files, loops, elapsed);

        long end = System.currentTimeMillis();
        System.out.println("Compiled " + files + " files " + loops + " times in " + (end - vmStart - maxBeanOverHead) + " ms");
        for (int i = 0; i < loops; i++) {
            double ms = elapsed[i] / 10000000.0;
            System.out.format("%3d = %6.3f ms", i, ms);
            if (files > 0 && ms > 0) {
                System.out.format(" %6.3f files per ms", files / ms);
            }
            System.out.println();
        }

        if (sleep) {
            // For memory size measurement.
            System.out.println("sleeping ...");
            Thread.sleep(1000000);
        }
    }

    static void run(int files, int loops, long[] elapsed) throws Throwable {
        JavacBench2 bench = new JavacBench2();

        long lastNanos = System.nanoTime();
        for (int i = 0; i < loops; i++) {
            if (files >= 0) {
                bench.setup(files);
                Map<String, byte[]> allClasses = bench.compile();
            }
            long now = System.nanoTime();
            elapsed[i] = now - lastNanos;
            lastNanos = now;
        }
    }
}

