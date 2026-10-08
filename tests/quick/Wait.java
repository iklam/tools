import javax.tools.JavaCompiler;
import javax.tools.ToolProvider;

public class Wait {
    public static void main(String args[]) throws Exception {
        if (args.length > 0) {
            if (args[0].equals("javac")) {
                JavaCompiler compiler = ToolProvider.getSystemJavaCompiler();
                int result = compiler.run(null, null, null, "HelloWorld.java");
                System.out.println("Done compile " + result);
            }
            System.out.println("calling GC");
            System.gc();
            System.out.println("Done");
        }
        Thread.sleep(1000000);
    }
}
