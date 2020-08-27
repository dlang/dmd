// https://issues.dlang.org/show_bug.cgi?id=21198

/*
TEST_OUTPUT:
---
fail_compilation/test21198.d(23): Error: copy constructor `test21198.U.this` cannot be used because it is annotated with `@disable`
---
*/

struct S
{
    this(ref inout(S) other) inout {}
}

union U
{
    S s;
}

void fun()
{
    U original;
    U copy = original;
}
