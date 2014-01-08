// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail6572.d(9): Deprecation: use of typedef is deprecated; use alias instead
---
*/

typedef int y;

// 11424
/*
TEST_OUTPUT:
---
fail_compilation/fail6572.d(18): Deprecation: use of typedef is deprecated; use alias instead
---
*/
typedef struct S { }
