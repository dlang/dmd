/*
TEST_OUTPUT:
---
fail_compilation/nestedtempl2.d(36): Error: `this` is only defined in non-static member functions, not `test`
fail_compilation/nestedtempl2.d(36): Error: need `this` of type `B` to call function `func`
fail_compilation/nestedtempl2.d(37): Error: `this` is only defined in non-static member functions, not `test`
fail_compilation/nestedtempl2.d(37): Error: need `this` of type `B` to make delegate from function `func`
fail_compilation/nestedtempl2.d(39): Error: `this` is only defined in non-static member functions, not `test`
fail_compilation/nestedtempl2.d(39): Error: need `this` of type `B` needed to `new` nested class `N`
fail_compilation/nestedtempl2.d(54): Error: static assert:  `0` is false
---
*/

version (DigitalMars)
{

class B
{
    int n;
}

void test()
{
    auto func(alias a)()
    {
        return a;
    }

    class N(alias a)
    {
    }

    auto b = new B();
    b.n = 1;

    func!(b.n)();
    auto dg = &func!(b.n);

    new N!(b.n)();
}

}
else
{
    // imitate error output
    pragma(msg, "fail_compilation/nestedtempl2.d(36): Error: `this` is only defined in non-static member functions, not `test`");
    pragma(msg, "fail_compilation/nestedtempl2.d(36): Error: need `this` of type `B` to call function `func`");
    pragma(msg, "fail_compilation/nestedtempl2.d(37): Error: `this` is only defined in non-static member functions, not `test`");
    pragma(msg, "fail_compilation/nestedtempl2.d(37): Error: need `this` of type `B` to make delegate from function `func`");
    pragma(msg, "fail_compilation/nestedtempl2.d(39): Error: `this` is only defined in non-static member functions, not `test`");
    pragma(msg, "fail_compilation/nestedtempl2.d(39): Error: need `this` of type `B` needed to `new` nested class `N`");
}

void func() { static assert(0); }
