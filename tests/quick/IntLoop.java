/*


rm -rf tmpclasses
mkdir tmpclasses
javac -d tmpclasses IntLoop.java
jar cf IntLoop.jar -C tmpclasses .

java -cp IntLoop.jar IntLoop

java -XX:AOTCacheOutput=IntLoop.aot -cp IntLoop.jar

java -XX:AOTMode=on -XX:AOTCache=IntLoop.aot -cp IntLoop.jar IntLoop


*/

public class IntLoop {
    int a;
    int counter;
    public static void main(String args[]) {
        for (int i = 0; i < 2; i++) {
            (new IntLoop()).doit();
        }
    }

    void doit() {
        counter = 0;
        for (int i = 0; i < 0x10000; i++) {
            test(a);
        }
        System.out.format("counter = 0x%x\n", counter);
    }

    void func() {
        counter += 1;
    }

    void test(int m) {
        counter += m * 0x2a2a2a;
        for (int i = 0; i < 0x7a7a7a; i++) {
            func();
        }
    }
}
