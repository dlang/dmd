// https://issues.dlang.org/show_bug.cgi?id=22118

/*
TEST_OUTPUT:
---
fail_compilation/fail22118.d(35): Error: cannot modify `this.v.a` in `const` function
        v.a = arg;   // this should not
        ^
---
*/

struct NeedsInit
{
    int n;
    @disable this();
}

union U
{
    NeedsInit a;
}

struct V
{
    NeedsInit a;
}

struct S
{
    U u;
    V v;
    this(const NeedsInit arg) const
    {
        u.a = arg;   // this should compile
        v.a = arg;   // this should not
    }
}
