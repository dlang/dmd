// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

/*
TEST_OUTPUT:
---
fail_compilation/imports/diag9210stdcomplex.d(13): Error: template instance Complex!real does not match template declaration Complex(T) if (isFloatingPoint!T)
fail_compilation/imports/diag9210b.d(6): Error: undefined identifier A, did you mean interface B?
---
*/

import imports.diag9210b;
interface A {}
