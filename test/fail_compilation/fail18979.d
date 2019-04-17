// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail18979.d(14): Error: `imports.imp18979.Foo.__ctor(A)(A a)` is not visible from module `fail18979`
fail_compilation/fail18979.d(14): Error: no property `__ctor` for type `Foo`, did you mean `imports.imp18979.Foo.__ctor(A)(A a)`?
----
*/

import imports.imp18979;

void main()
{
    auto f = Foo(42);
}
