// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/test15966.d(14): Deprecation: test15966a.T1 is not visible from module test15966
---
*/
module pkg.test15966;

import imports.test15966base;

class Derived : Base
{
    T1 v1;
    T2 v2;
}
