/*
TEST_OUTPUT:
---
fail_compilation/dip22b.d(11): Error: undefined identifier `Foo`, did you mean variable `foo`?
---
*/
module pkg.dip22;

import imports.dip22b;

Foo foo;
