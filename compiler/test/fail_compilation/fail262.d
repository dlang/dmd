/*
TEST_OUTPUT:
---
fail_compilation/fail262.d(23): Error: function `void fail262.B.f() const` does not override any function, did you mean to override `void fail262.A.f() shared const`?
---
*/

// https://issues.dlang.org/show_bug.cgi?id=1645
// can override base class' const method with non-const method
import core.stdc.stdio;

class A
{
    int x;
    shared const void f()
    {
        printf("A\n");
    }
}

class B : A
{
    override const void f()
    {
        //x = 2;
        printf("B\n");
    }
}

void main()
{
    A y = new B;
    y.f;
}
