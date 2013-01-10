// PERMUTE_ARGS: -de -dw
/*
TEST_OUTPUT:
---
fail_compilation/fail6572.d(11): Deprecation: use of typedef is deprecated; use alias instead
fail_compilation/fail6572.d(11): Deprecation: use of typedef is deprecated; use alias instead
---
*/
// Issue 6572 - Deprecate typedef

typedef int y;
