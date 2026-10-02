/*
TEST_OUTPUT:
---
fail_compilation/fail229.d(10): Error: array index $?:32=4294967295|18446744073709551615$ overflow
---
*/

// https://issues.dlang.org/show_bug.cgi?id=1936
// Error with no line number (array dimension overflow)
static int[] x = [-1: 1];
