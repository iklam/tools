import java.lang.management.ManagementFactory;
import java.lang.management.RuntimeMXBean;
import com.sun.tools.javac.Main;
import java.io.*;

public class JavacHelloWorld {
    static final String className = "HelloWorldTemp";
    static final String fileName = className + ".java";

    public static void main(String args[]) throws Exception {
        long mainStart = System.currentTimeMillis();
        RuntimeMXBean runtimeMXBean = ManagementFactory.getRuntimeMXBean();
        // This includes all the time spent inside the JVM before main() is reached
        // (since os::Posix::init is called and initial_time_count is initialized).
        long vmStart = runtimeMXBean.getStartTime();
        long maxBeanOverHead = System.currentTimeMillis() - mainStart;

        int loops = 50;
        if (args.length > 0) {
            loops = Integer.parseInt(args[0]);
        }
        System.out.println("huh");
        writeFile();
        run(loops);
        System.out.println("ho");

        long end = System.currentTimeMillis();
        System.out.println("Compiled HelloWorldTemp.java " + loops + " times in " + (end - vmStart - maxBeanOverHead) + "ms");
    }

    static void run(int loops) throws Exception {
        String args[] = new String[] {fileName};

        for (int i = 0; i < loops; i++) {
            Main.main(args);
        }
    }

    static void writeFile() throws Exception {
        FileOutputStream fos = new FileOutputStream(fileName);
        PrintStream pos = new PrintStream(fos);
        pos.println("public class " + className + " {\n" +
                    "    public static void main(String[] args) {\n" +
                    "        System.out.println(\"Hello World \");\n" +
                    "    }\n" +
                    "}");
        pos.close();
    }
}
