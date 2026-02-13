public class CodeSourceTest {
    static void main(String args[]) {
        var cs = CodeSourceTest.class.getProtectionDomain().getCodeSource();
        System.out.println("CodeSource = " + cs);
        var loc = cs.getLocation();
        System.out.println("Location class = " + loc.getClass());
        System.out.println("Location = " + loc);
        System.out.println("Location path = " + loc.getPath());
    }
}
