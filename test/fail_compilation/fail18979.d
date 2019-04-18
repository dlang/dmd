// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail18979.d(13): Error: no property `__ctor` for type `Foo`, did you mean `imports.imp18979.Foo.__ctor(A)(A a)`?
----
*/

import imports.imp18979;

void main()
{
    auto f = Foo(42);
}
