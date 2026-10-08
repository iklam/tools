/*


rm -rf tmpclasses
mkdir tmpclasses
javac -d tmpclasses LambdaLoop.java
jar cf LambdaLoop.jar -C tmpclasses .

java -cp LambdaLoop.jar LambdaLoop

java -XX:AOTCacheOutput=LambdaLoop.aot -cp LambdaLoop.jar

java -XX:AOTMode=on -XX:AOTCache=LambdaLoop.aot -cp LambdaLoop.jar LambdaLoop


*/

public class LambdaLoop {
    int a;
    int y;
    public static void main(String args[]) {
        for (int i = 0; i < 2; i++) {
            (new LambdaLoop()).doit1();
            (new LambdaLoop()).doit2();
        }
    }

    void doit1() {
        y = 0;
        for (int i = 0; i < 0x10000; i++) {
            test1(a);
        }
        System.out.format("y = 0x%x\n", y);
    }

    void doit2() {
        y = 0;
        for (int i = 0; i < 0x10000; i++) {
            test2(a);
        }
        System.out.format("y = 0x%x\n", y);
    }

    void func() {
        y += 1;
    }

    void test1(int m) {
        y += m * 0x191919;
        for (int i = 0; i < 0x595959; i++) {
            func();
        }
    }

    void test2(int m) {
        y += m * 0x292929;
        Runnable r = () -> {
            y += 1;
        };
        for (int i = 0; i < 0x595959; i++) {
            r.run();
        }
    }
}
