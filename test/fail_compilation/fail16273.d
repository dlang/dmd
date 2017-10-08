/*
TEST_OUTPUT:
---
fail_compilation/fail16273.d(37): Error: cannot create instance of abstract class C
fail_compilation/fail16273.d(38): Error: cannot create instance of abstract class C2
fail_compilation/fail16273.d(15): Error: template instance fail16273.D!() error instantiating
fail_compilation/fail16273.d(22):        instantiated from here: A!()
---
*/

template MixFunc2() { abstract override void func2(); }

class A()
{
    alias MyD = D!();
}

class B
{
    void func1() {}
    void func2() {}
    alias MyA = A!();
}

class C : B
{
    abstract override void func1() {}
}

class C2 : B
{
    mixin MixFunc2;
}

class D() : A!()
{
    void test() { new C; }
    void test2() { new C2; }
}
