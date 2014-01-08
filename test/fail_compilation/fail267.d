/*
TEST_OUTPUT:
---
fail_compilation/fail267.d(15): Error: no property 'foo' for type 'void'
---
*/

class C
{
    template Bar()
    {
    }
}

typeof(C.Bar.foo) quux;
