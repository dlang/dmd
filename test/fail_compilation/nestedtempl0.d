/*
TEST_OUTPUT:
---
fail_compilation/nestedtempl0.d(22): Error: class `nestedtempl0.K.D!(1, B!(a)).D` doesn't need a frame pointer, but super class `B` needs the frame pointer of `main`
fail_compilation/nestedtempl0.d(32): Error: template instance `nestedtempl0.K.D!(1, B!(a))` error instantiating
fail_compilation/nestedtempl0.d(22): Error: class `nestedtempl0.main.fun.D!(b, B!(a)).D` needs the frame pointer of `fun`, but super class `B` needs the frame pointer of `main`
fail_compilation/nestedtempl0.d(37): Error: template instance `nestedtempl0.main.fun.D!(b, B!(a))` error instantiating
fail_compilation/nestedtempl0.d(51): Error: static assert:  `0` is false
---
*/

version (DigitalMars)
{

class K
{
    class B(alias a)
    {

    }

    class D(alias a, T) : T
    {

    }
}

void main()
{
    int a;
    auto k = new K;
    auto d = k.new K.D!(1, K.B!a);

    auto fun()
    {
        int b;
        auto o = k.new K.D!(b, K.B!a);
    }
}

}
else
{
    // imitate error output
    pragma(msg, "fail_compilation/nestedtempl0.d(22): Error: class `nestedtempl0.K.D!(1, B!(a)).D` doesn't need a frame pointer, but super class `B` needs the frame pointer of `main`");
    pragma(msg, "fail_compilation/nestedtempl0.d(32): Error: template instance `nestedtempl0.K.D!(1, B!(a))` error instantiating");
    pragma(msg, "fail_compilation/nestedtempl0.d(22): Error: class `nestedtempl0.main.fun.D!(b, B!(a)).D` needs the frame pointer of `fun`, but super class `B` needs the frame pointer of `main`");
    pragma(msg, "fail_compilation/nestedtempl0.d(37): Error: template instance `nestedtempl0.main.fun.D!(b, B!(a))` error instantiating");
}

void func() { static assert(0); }
