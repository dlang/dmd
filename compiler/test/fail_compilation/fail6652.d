// REQUIRED_ARGS: -de

/******************************************/
// https://issues.dlang.org/show_bug.cgi?id=6652

/*
TEST_OUTPUT:
---
fail_compilation/fail6652.d(22): Error: cannot modify `const` expression `i`
fail_compilation/fail6652.d(25): Deprecation: `foreach` range variable `i` cannot be `ref`
fail_compilation/fail6652.d(25):        use a `for` loop instead
fail_compilation/fail6652.d(32): Error: cannot modify `const` expression `i`
fail_compilation/fail6652.d(35): Deprecation: `foreach` array index variable `i` cannot be `ref`
fail_compilation/fail6652.d(35):        use a `for` loop instead
---
*/

void main()
{
    foreach (const i; 0..2)
    {
        ++i;
    }

    foreach (ref const i; 0..2)
    {
        ++i;
    }

    foreach (const i, e; [1,2,3,4,5])
    {
        ++i;
    }

    foreach (ref const i, e; [1,2,3,4,5])
    {
        ++i;
    }
}
