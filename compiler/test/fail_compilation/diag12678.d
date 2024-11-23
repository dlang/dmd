/*
TEST_OUTPUT:
---
fail_compilation/diag12678.d(31): Error: const field `cf1` initialized multiple times
        cf1 = x;
        ^
fail_compilation/diag12678.d(30):        Previous initialization is here.
        cf1 = x;
        ^
fail_compilation/diag12678.d(34): Error: immutable field `if1` initialized multiple times
        if1 = x;
        ^
fail_compilation/diag12678.d(33):        Previous initialization is here.
        if1 = x;
        ^
fail_compilation/diag12678.d(37): Error: const field `cf2` initialization is not allowed in loops or after labels
            cf2 = x;
            ^
---
*/

struct S
{
    const int cf1;
    const int cf2;
    immutable int if1;

    this(int x)
    {
        cf1 = x;
        cf1 = x;

        if1 = x;
        if1 = x;

        foreach (i; 0 .. 5)
            cf2 = x;
    }
}
