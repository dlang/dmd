// https://issues.dlang.org/show_bug.cgi?id=7524
/*
TEST_OUTPUT:
---
fail_compilation/fail7524b.d(9): Error: #line integer ["filespec"]\n expected
---
*/

#line 47 __VERSION__
