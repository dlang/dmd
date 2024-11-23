/*
EXTRA_FILES: imports/fail356.d
TEST_OUTPUT:
---
fail_compilation/fail356c.d(11): Error: variable `fail356c.foo` conflicts with import `fail356c.foo` at fail_compilation/fail356c.d(10)
int foo; // collides with renamed import
    ^
---
*/
import foo = imports.fail356;
int foo; // collides with renamed import
