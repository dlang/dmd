/*
TEST_OUTPUT:
---
fail_compilation/nestedtempl1.d(28): Error: modify `inout` to `mutable` is not allowed inside `inout` function
fail_compilation/nestedtempl1.d(38): Error: static assert:  `0` is false
---
*/

version (DigitalMars)
{

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

}
else
{
    // imitate error output
    pragma(msg, "fail_compilation/nestedtempl1.d(28): Error: modify `inout` to `mutable` is not allowed inside `inout` function");
}

void func() { static assert(0); }
