public class Lambda0 {
    public static void main(String[] args) throws Throwable  {
        doit(() -> {
                Thread.dumpStack();
            });
    }
    static void doit(Runnable r) {
        r.run();
    }
}
