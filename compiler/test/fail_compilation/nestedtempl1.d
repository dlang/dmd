/*
TEST_OUTPUT:
---
fail_compilation/nestedtempl1.d(20): Deprecation: function `nestedtempl1.main.bar!(a).bar` function requires a dual-context, which is deprecated
        ref inout(int) bar(alias a)() inout
                       ^
fail_compilation/nestedtempl1.d(32):        instantiated from here: `bar!(a)`
    o.bar!a() = 1;      // bad!
     ^
fail_compilation/nestedtempl1.d(32): Error: modify `inout` to `mutable` is not allowed inside `inout` function
    o.bar!a() = 1;      // bad!
           ^
---
*/

auto foo(ref inout(int) x)
{
    struct S
    {
        ref inout(int) bar(alias a)() inout
        {
            return x;
        }
    }
    return S();
}

void main()
{
    int a;
    auto o = foo(a);
    o.bar!a() = 1;      // bad!
}
