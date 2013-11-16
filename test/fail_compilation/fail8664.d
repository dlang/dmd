// 8664
// REQUIRED_ARGS: -d -g -c
/*
TEST_OUTPUT:
---
fail_compilation/fail8664.d(11): Error: typedef fail8664.foo circular definition
---
*/

typedef foo bar;
typedef bar foo;

