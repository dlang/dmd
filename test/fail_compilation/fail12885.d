/*
TEST_OUTPUT:
---
fail_compilation/fail12885.d(19): Error: cannot implicitly convert expression `c` of type `const(U)` to `U`
fail_compilation/fail12885.d(34): Error: cannot implicitly convert expression `cr` of type `const(R11257)` to `R11257`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=12885
union U
{
    int i;
    int* p;
}

void test12885()
{
    const U c;
    U m = c;
}

struct R11257
{
    union
    {
        const(Object) original;
        Object stripped;
    }
}

void test11257()
{
    const(R11257) cr;
    R11257 mr = cr;  // Error: cannot implicitly convert expression (cr) of type const(R) to R
}

