/*
TEST_OUTPUT:
---
fail_compilation/fail172.d(33): Error: cannot modify `const` expression `c1.x`
    c1.x = 3;
    ^
fail_compilation/fail172.d(34): Error: cannot modify `const` expression `c2.x`
    c2.x = 3;
    ^
fail_compilation/fail172.d(38): Error: cannot modify `const` expression `s1.x`
    s1.x = 3;
    ^
fail_compilation/fail172.d(39): Error: cannot modify `const` expression `s2.x`
    s2.x = 3;
    ^
---
*/

class C
{
    int x;
}

struct S
{
    int x;
}

void main()
{
    const(C) c1 = new C();
    const C  c2 = new C();
    c1.x = 3;
    c2.x = 3;

    const(S) s1;
    const S  s2;
    s1.x = 3;
    s2.x = 3;
}
