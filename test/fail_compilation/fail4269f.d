/*
TEST_OUTPUT:
---
fail_compilation/fail4269f.d(9): Error: alias fail4269f.X6 cannot resolve
---
*/

static if (is(typeof(X6))) {}
alias X6 X6;
