// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail18979.d(13): Deprecation: `imports.imp18979.Foo.__ctor(A)(A a)` is not visible from module `fail18979`
---
*/

import imports.imp18979;

void main()
{
    auto f = Foo(42);
}
