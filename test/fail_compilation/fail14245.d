// https://issues.dlang.org/show_bug.cgi?id=14245

/*
TEST_OUTPUT:
---
fail_compilation/fail14245.d(16): Error: cannot take address of uninitialized `immutable` field `this.x`
fail_compilation/fail14245.d(28): Error: cannot take address of uninitialized `immutable` field `this.a`
---
*/

struct S
{
    immutable int x;
    this(int a)
    {
        immutable int* b = &this.x;
        this.x = a;
     }
}

immutable(int)* g;

struct X
{
    int a = 10;
    immutable this(int x)
    {
        g = &a;
        a = 42;
    }
}
