/*
TEST_OUTPUT:
---
fail_compilation/fail177.d(34): Error: cannot modify `immutable` expression `j`
    j = 4;
    ^
fail_compilation/fail177.d(36): Error: cannot modify `const` expression `i`
    i = 4;
    ^
fail_compilation/fail177.d(38): Error: cannot modify `const` expression `s1.x`
    s1.x = 3;
    ^
fail_compilation/fail177.d(39): Error: cannot modify `const` expression `*s1.p`
    *s1.p = 4;
    ^
fail_compilation/fail177.d(41): Error: cannot modify `const` expression `s2.x`
    s2.x = 3;
    ^
fail_compilation/fail177.d(42): Error: cannot modify `const` expression `*s2.p`
    *s2.p = 4;
    ^
---
*/

struct S
{
    int x;
    int* p;
}

void test(const(S) s1, const S s2, const(int) i)
{
    immutable int j = 3;
    j = 4;

    i = 4;

    s1.x = 3;
    *s1.p = 4;

    s2.x = 3;
    *s2.p = 4;
}
