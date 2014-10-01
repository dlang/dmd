// 8664
// REQUIRED_ARGS: -d -g -c
/*
TEST_OUTPUT:
---
fail_compilation/fail8664.d(11): Error: use alias instead of typedef
fail_compilation/fail8664.d(12): Error: use alias instead of typedef
---
*/

typedef foo bar;
typedef bar foo;

