/*
REQUIRED_ARGS: -unittest
TEST_OUTPUT:
---
fail_compilation/test19176.d(13): Error: `tuple()` has no effect
---
*/

// https://issues.dlang.org/show_bug.cgi?id=19176

void main()
{
    __traits(getUnitTests, foo);
}

template foo()
{
    static if(true)
    {
        enum bar;
    }
    else
    {
        enum bar;
    }
}
