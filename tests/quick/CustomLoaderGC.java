import java.io.File;
import java.net.URLClassLoader;
import java.net.URL;

public class CustomLoaderGC {
    static private URL[] initURLs() {
        try {
            String jar = "HelloLoop.jar";
            URL url = new File(jar).toURI().toURL();
            URL[] urls = new URL[] {url};
            return urls;
        } catch (Throwable t) {
            t.printStackTrace();
            System.exit(1);
            return null;
        }
    }

    public static void main(String args[]) throws Throwable {
        int n = 0;
        while (true) {
            long start = System.currentTimeMillis();
            URLClassLoader loader = new URLClassLoader(initURLs());
            Class<?> c = loader.loadClass("HelloLoop");
            System.out.println(c.newInstance());
            System.out.println(n + ": Elapsed = " + (System.currentTimeMillis() - start) + ", mem = " + Runtime.getRuntime().freeMemory());
            System.gc();
            n++;
        }
    }
}

/*
javac CustomLoaderGC.java
jar cf CustomLoaderGC.jar CustomLoaderGC.class

javac HelloLoop.java
jar cf HelloLoop.jar HelloLoop.class







*/
