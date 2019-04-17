/*
REQUIRED_ARGS:
TEST_OUTPUT:
---
fail_compilation/dip22b.d(12): Error: undefined identifier `Foo`, did you mean struct `Foo`?
---
*/
module pkg.dip22;

import imports.dip22b;

Foo foo;
