/*
TEST_OUTPUT:
---
fail_compilation/fail262.d(23): Error: function `const void fail262.B.f()` does not override any function, did you mean to override `shared const void fail262.A.f()`?
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
