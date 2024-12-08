/*
TEST_OUTPUT:
---
fail_compilation/fail229.d(15): Error: array index 18446744073709551615 overflow
static int[] x = [-1: 1];
                 ^
fail_compilation/fail229.d(15): Error: array dimension overflow
static int[] x = [-1: 1];
                 ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=1936
// Error with no line number (array dimension overflow)
static int[] x = [-1: 1];
