// https://issues.dlang.org/show_bug.cgi?id=18719

// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail18719.d(29): Deprecation: immutable field `x` was initialized in a previous constructor call
---
*/

struct S
{
    int x = -1;
    this(int y) immutable
    {
        x = y;
        import core.stdc.stdio;
        printf("Ctor called with %d\n", y);
    }
    void opAssign(int) immutable;
}

class C
{
    S x;
    this() immutable
    {
        this(42); /* Initializes x. */
        x = 13; /* Breaking immutable, or ok? */
    }
    this(int x) immutable
    {
        this.x = x;
    }
}

void main()
{
    new immutable C;
}
