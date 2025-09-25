import java.lang.reflect.Field;
import java.lang.reflect.Method;
import jdk.jfr.Event;

public class ReflectExcludedClass {
    static void main(String args[]) throws Throwable {
        BadField.test();
        BadMethod.test();
    }
}

class BadField {
    static void test() throws Throwable {
        Field f = BadField.class.getDeclaredField("test");
        System.out.println("field = " + f.get(null));
    }

    static Event test;
}

    
class BadMethod {
    java.awt.Frame[] not_reflected_field;

    static void test() throws Throwable {
        Class<?>[] cls = BadMethod.class.getClasses();
        for (var c : cls) {
            System.out.println(c);
        }
        Method m = BadMethod.class.getDeclaredMethod("test", Object.class, Event.class);
        m.invoke(null, m, null);
    }

    static void test(Object o, Event e) {
        System.out.println("test() called");
    }

    public static class MyEvent extends Event {}
}

    
