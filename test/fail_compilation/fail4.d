// REQUIRED_ARGS: -d
/*
TEST_OUTPUT:
---
fail_compilation/fail4.d(12): Error: typedef fail4.foo circular definition
---
*/

// On DMD0.165 fails only with typedef, not alias

typedef foo bar;
typedef bar foo;
