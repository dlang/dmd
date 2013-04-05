/*
TEST_OUTPUT:
---
fail_compilation/fail4269g.d(10): Error: alias fail4269g.X7 cannot alias an expression d7[1]
---
*/

int[2] d7;
static if (is(typeof(X7.init))) {}
alias d7[1] X7;
