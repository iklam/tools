package moda;

public class HelloModule {
    public static void main(String args[]) {
        Thread.dumpStack();
        System.out.println("Hello from HelloModule");
        System.out.println(HelloModule.class.getModule());
        System.out.println(HelloModule.class.getProtectionDomain());
        System.out.println(HelloModule.class.getProtectionDomain().getCodeSource());
    }
}


/*

hwo0
hwo1
hwo2


(1) Use --module-path with static archive = OK
hwo2 -- --module-path ~/tmp/modules/HelloModule.jar -Xlog:class+load -m moda 

(2) Use --module-path with static archive, dump dynamic archive = OK (test2.jsa is created)
hwo2 -- --module-path ~/tmp/modules/HelloModule.jar -XX:ArchiveClassesAtExit=test2.jsa -m moda 

(3) Use test2.jsa 
hwo2 -- --module-path ~/tmp/modules/HelloModule.jar -XX:SharedArchiveFile=test2.jsa -m moda 

===============================================================================

mdo0
mdo1
mdo2

(a) Use extra --classpath with static archive = OK
mdo2 -- -cp ~/tmp/HelloWorld.jar -Xlog:class+load | grep Hello

(b) Use extra --classpath with static archive, use main class from CP = OK
mdo2 -- -cp ~/tmp/HelloWorld.jar -Xlog:class+load -p ~/tmp/modules/HelloModule.jar HelloWorld

(c) Use extra --classpath with static archive, create dynamic archive = test3.jsa created
mdo2 -- -cp ~/tmp/HelloWorld.jar -p ~/tmp/modules/HelloModule.jar -XX:ArchiveClassesAtExit=test3.jsa -Xlog:cds HelloWorld

(d) can test3.jsa be used??
mdo2 -- -cp ~/tmp/HelloWorld.jar -p ~/tmp/modules/HelloModule.jar -XX:SharedArchiveFile=test3.jsa -Xlog:cds HelloWorld



*/
