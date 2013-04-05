/*
TEST_OUTPUT:
---
fail_compilation/fail4269d.d(9): Error: undefined identifier Y4, did you mean alias X4?
---
*/

static if (is(typeof(X4.init))) {}
alias Y4 X4;
