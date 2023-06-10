/*
TEST_OUTPUT:
---
fail_compilation/e15876_1.d(101): Error: valid scope identifiers are `exit`, `failure`, or `success`, not `x`
fail_compilation/e15876_1.d(102): Error: found `End of File` when expecting `)`
---
*/

#line 100

o[{scope(x
