// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
fail_compilation/test15785.d(15): Error: no property `foo` for type `imports.test15785.Base`, did you mean non-visible function `foo`?
fail_compilation/test15785.d(16): Error: undefined identifier `bar`, did you mean non-visible function `bar`?
---
*/
import imports.test15785;

class Derived : Base
{
    void test()
    {
        super.foo();
        bar();
    }
}
