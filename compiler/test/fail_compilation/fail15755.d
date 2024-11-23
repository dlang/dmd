/*
TEST_OUTPUT:
---
fail_compilation/fail15755.d(30): Error: `AliasSeq!(123)` has no effect
    getattribute!(__traits(getMember, Foo, "a"));
    ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=15755

struct Foo
{
    @(123)
    int a;
}

template Attributes(As...)
{
    alias Attributes = As;
}

template getattribute(alias member, alias attrs = Attributes!(__traits(getAttributes, member)))
{
    alias getattribute = attrs;
}

void main()
{
    getattribute!(__traits(getMember, Foo, "a"));
}
