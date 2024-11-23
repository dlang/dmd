/*
TEST_OUTPUT:
---
fail_compilation/fail267.d(17): Error: template `Bar()` does not have property `foo`
typeof(C.Bar.foo) quux;
            ^
---
*/

class C
{
    template Bar()
    {
    }
}

typeof(C.Bar.foo) quux;
