import java.security.AccessController;
import java.security.*;

public class App {
    public static void main(String args[]) {
        if (args.length > 0) {
            return;
        }
        System.out.println("CodeSource = " + App.class.getProtectionDomain().getCodeSource());
        try {
            AccessController.checkPermission(new RuntimePermission("setIO"));
            System.out.println("Good: I have permission for 'setIO'");
        } catch (Throwable t) {
            System.out.println("Bad: I don't have permission for 'setIO'");
            t.printStackTrace(System.out);
        }
    }
}
