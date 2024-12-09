// EXTRA_FILES: imports/test15785.d
/*
TEST_OUTPUT:
---
fail_compilation/test15785.d(23): Error: no property `foo` for `super` of type `imports.test15785.Base`
        super.foo();
             ^
fail_compilation/imports/test15785.d(3):        class `Base` defined here
class Base
^
fail_compilation/test15785.d(24): Error: undefined identifier `bar`
        bar();
        ^
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
