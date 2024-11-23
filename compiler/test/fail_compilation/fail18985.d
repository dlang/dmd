/*
TEST_OUTPUT:
---
fail_compilation/fail18985.d(20): Error: `foo` is not a scalar, it is a `object.Object`
    foo += 1;
    ^
fail_compilation/fail18985.d(21): Error: `bar` is not a scalar, it is a `shared(Object)`
    bar += 1;
    ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=18985

Object foo;
shared Object bar;

void main()
{
    foo += 1;
    bar += 1;
}
