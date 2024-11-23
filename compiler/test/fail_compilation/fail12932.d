/*
TEST_OUTPUT:
---
fail_compilation/fail12932.d(15): Error: array literal in `@nogc` function `fail12932.foo` may cause a GC allocation
    foreach (ref e; [1,2,3])
                    ^
fail_compilation/fail12932.d(19): Error: array literal in `@nogc` function `fail12932.foo` may cause a GC allocation
    foreach (ref e; [1,2,3])
                    ^
---
*/

int* foo() @nogc
{
    foreach (ref e; [1,2,3])
    {
    }

    foreach (ref e; [1,2,3])
    {
        return &e;
    }
}
