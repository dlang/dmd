// https://issues.dlang.org/show_bug.cgi?id=20965
/*
TEST_OUTPUT:
---
fail_compilation/fail20965.d(16): Error: `struct S` implicitly-generated postblit hides copy constructor.
fail_compilation/fail20965.d(16):        The field postblit will have priority over the copy constructor.
fail_compilation/fail20965.d(16):        To change this, the postblit should be disabled for `struct S`
---
*/

struct C
{
    this(this) {}
}

struct S
{
    C c;
    @disable this(ref typeof(this));
}

void main()
{
    S s1;
    auto s2 = s1; // problem
}
