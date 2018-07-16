/* REQUIRED_ARGS: -de
 * PERMUTE_ARGS:
 * TEST_OUTPUT:
---
fail_compilation/fail19095.d(13): Deprecation: mismatched array lengths, 2 and 1
fail_compilation/fail19095.d(14): Deprecation: mismatched array lengths, 2 and 1
fail_compilation/fail19095.d(15): Deprecation: mismatched array lengths, 2 and 1
---
 */

// https://issues.dlang.org/show_bug.cgi?id=1XXXX

int[2] ARR = [1];
static int[2] static_arr = [1];
__gshared int[2] gshared_arr = [1];
int[3] asoc_arr = [1:2];
