// REQUIRED_ARGS: -w
// PERMUTE_ARGS:

/*
TEST_OUTPUT:
---
fail_compilation/warn7444.d(30): Warning: explicit element-wise assignment (sa)[] = e is better than sa = e
fail_compilation/warn7444.d(32): Error: cannot implicitly convert expression (e) of type int to int[]
fail_compilation/warn7444.d(37): Warning: explicit element-wise assignment (sa)[] = sa[] is better than sa = sa[]
fail_compilation/warn7444.d(38): Warning: explicit element-wise assignment sa[] = (sa)[] is better than sa[] = sa
fail_compilation/warn7444.d(41): Warning: explicit element-wise assignment (sa)[] = (da)[] is better than sa = da
fail_compilation/warn7444.d(42): Warning: explicit element-wise assignment (sa)[] = da[] is better than sa = da[]
fail_compilation/warn7444.d(43): Warning: explicit element-wise assignment sa[] = (da)[] is better than sa[] = da
fail_compilation/warn7444.d(47): Warning: explicit slice assignment da = (sa)[] is better than da = sa
fail_compilation/warn7444.d(49): Warning: explicit element-wise assignment da[] = (sa)[] is better than da[] = sa
fail_compilation/warn7444.d(54): Warning: explicit element-wise assignment da[] = (da)[] is better than da[] = da
---
*/

void test7444()
{
    int[2] sa;
    int[]  da;
    int    e;

    {
        // X: Changed accepts-invalid to rejects-invalid by this issue
        // a: slice assginment
        // b: element-wise assignment
        sa   = e;      // X
        sa[] = e;      // b
        da   = e;
        da[] = e;      // b

        // lhs is static array
        sa   = sa;     // b == identity assign
        sa   = sa[];   // X
        sa[] = sa;     // X
        sa[] = sa[];   // b

        sa   = da;     // X
        sa   = da[];   // X
        sa[] = da;     // X
        sa[] = da[];   // b

        // lhs is dynamic array
        da   = sa;     // X
        da   = sa[];   // a
        da[] = sa;     // X
        da[] = sa[];   // b

        da   = da;     // a == identity assign
        da   = da[];   // a
        da[] = da;     // X
        da[] = da[];   // b
    }
}
