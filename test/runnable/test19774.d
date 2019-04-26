/*
TEST_OUTPUT:
---
---
*/

C bar()
{
    return C(42);
}

C foo()
{
    return bar()[1];
}

struct C
{
    int x;

    ~this()
    {
        x = 0;
    }

    C opIndex(int a)
    {
        return this;
    }
}

void main()
{
    auto c = foo();
    assert(c.x == 42); /* fails; should pass */
}
