/*
TEST_OUTPUT:
---
fail_compilation/fail262.d(23): Error: function fail262.B.f does not override any function
---
*/

// Issue 1645 - can override base class' const method with non-const method

extern(C) int printf(const char*, ...);

class A
{
    int x;
    void f() shared const
    {
        printf("A\n");
    }
}

class B : A
{
    override void f() const
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
