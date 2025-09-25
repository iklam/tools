import jdk.jfr.Event;

public class OldClass {
    public static void main(String args[]) {
        System.out.println(get_OldA_from_NewB());
        System.out.println(OldClassWithVerifierConstraints.get_OldA_from_NewB());
        System.out.println(OldClassWithBadVerifierConstraints.get_Event_from_MyEvent());
        System.out.println(NewClassWithBadVerifierConstraints.get_MyEvent_from_MyEvent2());
        System.out.println(new MyEvent());
    }

    static OldA get_OldA_from_NewB() {
        return new NewB();
    }
}

class NewB extends OldA {}

class MyEvent extends Event {}
class MyEvent2 extends MyEvent {}

class NewClassWithBadVerifierConstraints {
    static MyEvent get_MyEvent_from_MyEvent2() {
        return new MyEvent2();
    }
}
