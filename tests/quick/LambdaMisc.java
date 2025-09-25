public class LambdaMisc {
    public static void main(String args[]) {
        UndetVarListener l = (x) -> {
            System.out.println("Custom");
        };
        l.varInstantiated();
        l.varBoundChanged(0);


        BadUndetVarListener bl = (x) -> {
            System.out.println("Custom");
        };
        bl.varInstantiated();
        bl.varBoundChanged(0);


        InterfaceWithEnum iwe = (x) -> {
            System.out.println("don't call me");
        };

        System.out.println(iwe);
    }

    static int initer(String cls) {
        System.out.println(cls + "::<clinit> called");
        return 123;
    }

}

// src/jdk.compiler/share/classes/com/sun/tools/javac/code/Type.java
interface UndetVarListener {
    void varBoundChanged(int x);
    default void varInstantiated() {
        System.out.println("Default");
    }
}

// src/jdk.compiler/share/classes/com/sun/tools/javac/code/Type.java
interface BadUndetVarListener {
    public static final int x = LambdaMisc.initer("BadUndetVarListener");
    void varBoundChanged(int x);
    default void varInstantiated() {
        System.out.println("Default");
    }
}

interface InterfaceWithEnum {
    void func(EnumWithClinit e);
}

enum EnumWithClinit {
    Dummy;
    static final int x = LambdaMisc.initer("EnumWithClinit");
}
