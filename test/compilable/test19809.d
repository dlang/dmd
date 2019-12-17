/*
TEST_OUTPUT:
---
---
*/

mixin template Impl(M...)
{
    int opCmp(Object o) { return 0; }
}

class C
{
    override
    {
        int function(int) fp = ((int x) => x);
        mixin Impl!("x", "y", ((int x) => x));
    }
}
