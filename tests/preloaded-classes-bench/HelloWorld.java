import static java.util.stream.Collectors.*;

public class HelloWorld {
    public static void main(String args[]) {
        var words = java.util.List.of("hello", "fuzzy", "world");
        System.out.println(words.stream().filter(w->!w.contains("u")).collect(joining(", ")));
        // => hello, world
    }
}
