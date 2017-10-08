// REQUIRED_ARGS: -o-

template MixFunc2() { override void func2(); }

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
    override void func1() {}
    mixin MixFunc2;
}

class D() : A!()
{
    void test() { new C; }
}
