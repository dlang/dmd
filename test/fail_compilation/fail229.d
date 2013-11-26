/*
TEST_OUTPUT:
---
fail_compilation/fail229.d(10): Error: array dimension overflow
---
*/

// Issue 1936 - Error with no line number (array dimension overflow)

static int[] x = [-1: 1];
