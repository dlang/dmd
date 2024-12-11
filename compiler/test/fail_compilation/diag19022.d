/*
TEST_OUTPUT:
---
fail_compilation/diag19022.d(20): Error: immutable field `b` initialized multiple times
        b = 2;
        ^
fail_compilation/diag19022.d(19):        Previous initialization is here.
        b = 2;
        ^
---
*/
// https://issues.dlang.org/show_bug.cgi?id=19022

struct Foo
{
    immutable int b;
    this(int a)
    {
        b = 2;
        b = 2;
    }
}
