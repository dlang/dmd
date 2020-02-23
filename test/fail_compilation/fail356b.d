/*
TEST_OUTPUT:
---
fail_compilation/fail356b.d(8): Error: variable `fail356b.bar` conflicts with alias `fail356b.bar` at fail_compilation/fail356b.d(7)
---
*/
import imports.fail356 : bar;
int bar; // collides with selective import
