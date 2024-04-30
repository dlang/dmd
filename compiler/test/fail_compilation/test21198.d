// https://issues.dlang.org/show_bug.cgi?id=21198

/*
TEST_OUTPUT:
---
fail_compilation/test21198.d(24): Error: generated copy constructor of type `inout ref @system inout(U)(return ref scope inout(U) p)` is disabled
fail_compilation/test21198.d(24):        some of the field types of struct `U` do not define a copy constructor that can handle such copies
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
