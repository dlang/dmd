// PERMUTE_ARGS: -w -dw -de -d

/******************************************/
// https://issues.dlang.org/show_bug.cgi?id=6652

/*
TEST_OUTPUT:
---
fail_compilation/fail6652.d(28): Error: cannot modify `const` expression `i`
        ++i;
          ^
fail_compilation/fail6652.d(33): Error: cannot modify `const` expression `i`
        ++i;
          ^
fail_compilation/fail6652.d(38): Error: cannot modify `const` expression `i`
        ++i;
          ^
fail_compilation/fail6652.d(43): Error: cannot modify `const` expression `i`
        ++i;
          ^
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
