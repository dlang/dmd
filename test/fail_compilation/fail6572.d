// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail6572.d(9): Error: use alias instead of typedef
---
*/

typedef int y;

// 11424
/*
TEST_OUTPUT:
---
fail_compilation/fail6572.d(18): Error: use alias instead of typedef
---
*/
typedef struct S { }
