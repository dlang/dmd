// REQUIRED_ARGS: -w

/*
TEST_OUTPUT:
---
fail_compilation/warn7444.d(24): Error: cannot implicitly convert expression `e` of type `int` to `int[]`
fail_compilation/warn7444.d(28): Deprecation: assignment of `sa` from itself has no side effect, to exercise assignment instead use `sa = sa.init`
fail_compilation/warn7444.d(44): Deprecation: assignment of `da` from itself has no side effect, to exercise assignment instead use `da = da.init`
---
*/

void test7444()
{
    int[2] sa;
    int[]  da;
    int    e;

    {
        // X: Changed accepts-invalid to rejects-invalid by this issue
        // a: slice assignment
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

/*
TEST_OUTPUT:
---
No warning
---
*/

void test10214()
{
    bool[1] arr;
    arr = 0;
    pragma(msg, "No warning");
}

/*
TEST_OUTPUT:
---
No warning
---
*/

struct S11228
{
    int[2] ii;
    alias ii this;
}
void test11228()
{
    S11228 s;
    int[2] ii;
    ii = s.ii; // OK
    ii = s;    // OK <- Warning
    pragma(msg, "No warning");
}
