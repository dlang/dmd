/*
TEST_OUTPUT:
---
fail_compilation/fail18979.d(12): Error: no property `__ctor` for type `imports.imp18979.Foo`
----
*/

import imports.imp18979;

void main()
{
    auto f = Foo(42);
}
