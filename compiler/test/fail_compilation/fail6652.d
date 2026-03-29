// https://issues.dlang.org/show_bug.cgi?id=6652

/*
TEST_OUTPUT:
---
fail_compilation/fail6652.d(19): Error: cannot modify `const` expression `i`
fail_compilation/fail6652.d(22): Deprecation: `foreach` range variable `i` cannot be `ref`
fail_compilation/fail6652.d(22):        use a `for` loop instead
fail_compilation/fail6652.d(24): Error: cannot modify `const` expression `i`
fail_compilation/fail6652.d(29): Error: cannot modify `const` expression `i`
fail_compilation/fail6652.d(34): Error: cannot modify `const` expression `i`
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
