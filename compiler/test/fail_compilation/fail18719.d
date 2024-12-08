// https://issues.dlang.org/show_bug.cgi?id=18719

/*
TEST_OUTPUT:
---
fail_compilation/fail18719.d(21): Error: declaration expected, not `^`
fail_compilation/fail18719.d(37): Error: unmatched closing brace
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
    void opAssign(int) immutable; // Add `^` to trigger the error
    ^
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
} // Add an extra brace to trigger the unmatched closing brace error
}

void main()
{
    new immutable C;
}
