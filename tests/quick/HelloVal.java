import java.util.ArrayList;
import jdk.internal.vm.annotation.NullRestricted;

public class HelloVal {
    static Foo foo = new Foo();
    public static void main(String args[]) {
        System.out.println("Hello Valhalla: " + foo);
    }
}

value class Point {
    static final long time = System.currentTimeMillis();
    final int x;
    final int y;
    Point(int x, int y) {
        this.x = x;
        this.y = y;
    }
}

class Foo {
    @NullRestricted
    Point p;
    int x;
    ArrayList<Object> list;
    Foo() {
        p = new Point(1, 2);
        x = 3;
        list = new ArrayList<>();
        super();
    }
}
