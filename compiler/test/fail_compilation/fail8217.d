/*
TEST_OUTPUT:
---
fail_compilation/fail8217.d(24): Error: `this` for `foo` needs to be type `D` not type `fail8217.D.C`
            return bar!().foo();
                         ^
---
*/

class D
{
    int x;
    template bar()
    {
        int foo()
        {
            return x;
        }
    }
    static class C
    {
        int foo()
        {
            return bar!().foo();
        }
    }
}
