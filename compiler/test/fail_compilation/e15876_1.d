/*
TEST_OUTPUT:
---
fail_compilation/e15876_1.d(8): Error: valid scope identifiers are `exit`, `failure`, or `success`, not `x`
fail_compilation/e15876_1.d(9): Error: found `End of File` when expecting `)`
---
*/
o[{scope(x
