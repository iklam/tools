/*

Does AOT-linked lambdas cause undersiable build-time initialization of user classes.


rm -rf tmpclasses
mkdir tmpclasses
javac -d tmpclasses LambdaMisc.java
jar cf LambdaMisc.jar -C tmpclasses .

java -XX:AOTCacheOutput=LambdaMisc.aot -cp LambdaMisc.jar -Xlog:aot+class=debug LambdaMisc | egrep '((LambdaMisc)|(BadUndetVarListener)|(EnumWithClinit))'

java -XX:AOTMode=on -XX:AOTCache=LambdaMisc.aot -cp LambdaMisc.jar LambdaMisc


*/

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

        Runnable refToStaticMethod = LambdaMisc::myStatic;
        refToStaticMethod.run();

        System.out.println(iwe);

        validate();
    }

    static long initer(String cls) {
        System.out.println(cls + "::<clinit> called");
        return timeStamp;
    }

    static final long timeStamp = System.currentTimeMillis();
    static int counter;
    static {
        counter ++;
        initer("LambdaMisc");
    }

    static void myStatic() {
        System.out.println("LambdaMisc::myStatic() called");
    }

    static void validate() {
        System.out.println("\n\nChecking ...\n");
        if (counter == 1 &&
            BadUndetVarListener.x == timeStamp && 
            EnumWithClinit.x == timeStamp) {
            System.out.println("Passed: User classes NOT initialized during AOT assembly");
        } else {
            System.out.println("FAILED");
            System.out.println("timeStamp = " + timeStamp);
            System.out.println("BadUndetVarListener.x = " + BadUndetVarListener.x);
            System.out.println("EnumWithClinit.x = " + EnumWithClinit.x);
        }
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
    public static final long x = LambdaMisc.initer("BadUndetVarListener");
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
    static final long x = LambdaMisc.initer("EnumWithClinit");
}
