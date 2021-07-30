/*
TEST_OUTPUT:
---
fail_compilation/test15828.d(19): Error: union type `U!(int, float)` should define opEquals
---
*/

// https://issues.dlang.org/show_bug.cgi?id=15828

union U(T1, T2)
{
    T1 a;
    T2 b;
}

void main()
{
    U!(int, float) u1, u2;
    assert (u1 == u2);
}
