/*
TEST_OUTPUT:
---
fail_compilation/nestedtempl2.d(38): Deprecation: function `nestedtempl2.B.func!(n).func` function requires a dual-context, which is deprecated
    auto func(alias a)()
         ^
fail_compilation/nestedtempl2.d(50):        instantiated from here: `func!(n)`
    func!(b.n)();
    ^
fail_compilation/nestedtempl2.d(50): Error: `this` is only defined in non-static member functions, not `test`
    func!(b.n)();
              ^
fail_compilation/nestedtempl2.d(50): Error: need `this` of type `B` to call function `func`
    func!(b.n)();
              ^
fail_compilation/nestedtempl2.d(51): Error: `this` is only defined in non-static member functions, not `test`
    auto dg = &func!(b.n);
              ^
fail_compilation/nestedtempl2.d(51): Error: need `this` of type `B` to make delegate from function `func`
    auto dg = &func!(b.n);
              ^
fail_compilation/nestedtempl2.d(53): Error: `this` is only defined in non-static member functions, not `test`
    new N!(b.n)();
    ^
fail_compilation/nestedtempl2.d(53): Error: need `this` of type `B` needed to `new` nested class `N`
    new N!(b.n)();
    ^
---
*/

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
