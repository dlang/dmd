// https://issues.dlang.org/show_bug.cgi?id=20965

/*
TEST_OUTPUT:
---
fail_compilation/fail20965.d(24): Error: copy constructor `fail20965.S.this` cannot be used because it is annotated with `@disable`
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

