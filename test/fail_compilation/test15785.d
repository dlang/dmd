// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
fail_compilation/test15785.d(17): Error: `imports.test15785.Base.foo` is not visible from module `test15785`
fail_compilation/test15785.d(17): Error: no property `foo` for type `imports.test15785.Base`, did you mean `imports.test15785.Base.foo`?
fail_compilation/test15785.d(18): Error: undefined identifier `bar`, did you mean function `bar`?
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
