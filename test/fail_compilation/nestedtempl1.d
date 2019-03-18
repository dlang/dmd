/*
TEST_OUTPUT:
---
fail_compilation/nestedtempl1.d(24): Error: modify `inout` to `mutable` is not allowed inside `inout` function
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
