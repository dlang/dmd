/*
TEST_OUTPUT:
---
fail_compilation/fail66.d(28): Error: constructor `fail66.C1.this` missing initializer for const field `y`
    this() {}
    ^
fail_compilation/fail66.d(39): Error: cannot modify `const` expression `c.y`
    c.y = 3;
    ^
fail_compilation/fail66.d(48): Error: cannot modify `const` expression `this.y`
        y = 6;
        ^
fail_compilation/fail66.d(58): Error: cannot modify `const` expression `x`
        x = 4;
        ^
fail_compilation/fail66.d(66): Error: cannot modify `const` expression `z5`
    z5 = 4;
    ^
fail_compilation/fail66.d(76): Error: cannot modify `const` expression `c.y`
        c.y = 8;
        ^
---
*/

class C1
{
    const int y;
    this() {}
}

class C2
{
    const int y;
    this() { y = 7; }
}
void test2()
{
    C2 c = new C2();
    c.y = 3;
}

class C3
{
    const int y;
    this() { y = 7; }
    void foo()
    {
        y = 6;
    }
}

class C4
{
    static const int x;
    shared static this() { x = 5; }
    void foo()
    {
        x = 4;
    }
}

const int z5;
shared static this() { z5 = 3; }
void test5()
{
    z5 = 4;
}

class C6
{
    const int y;
    this()
    {
        C6 c = this;
        y = 7;
        c.y = 8;
    }
}
