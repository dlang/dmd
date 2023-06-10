/*
TEST_OUTPUT:
---
fail_compilation/e15876_3.d(27): Error: unexpected `(` in declarator
fail_compilation/e15876_3.d(27): Error: basic type expected, not `=`
fail_compilation/e15876_3.d(28): Error: found `End of File` when expecting `(`
---
*/
#line 27
d(={for
