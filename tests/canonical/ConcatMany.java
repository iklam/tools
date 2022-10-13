public class ConcatMany {
    static String s1 = "Hello ";
    static String s2 = "World";

    public static void main(String[] args) throws Throwable  {
        System.out.println(s1 + s2);
        System.out.println("Hello " + s2);
        System.out.println(s1 + "World");
        System.out.println("Has " + (args.length == 0 ? "zero" : "nonzero") + " args");
        System.out.println("Has " + args.length + " args");
        System.out.println("Args: " + args + ", class = " + ConcatMany.class);
    }
}
