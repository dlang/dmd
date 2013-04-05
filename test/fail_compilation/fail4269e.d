// REQUIRED_ARGS: -d

/*
TEST_OUTPUT:
---
fail_compilation/fail4269e.d(11): Error: undefined identifier Y5, did you mean typedef X5?
---
*/

static if (is(typeof(X5.init))) {}
typedef Y5 X5;
