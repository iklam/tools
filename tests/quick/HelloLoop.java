public class HelloLoop {
    public volatile static int f;

    public HelloLoop() {
        for (f = 0; f < 100000; f++) {}

    }
}
