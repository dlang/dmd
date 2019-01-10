/*
TEST_OUTPUT:
---
fail_compilation/fail7524a.d(11): Error: #line integer ["filespec"]\n expected
fail_compilation/fail7524a.d(11): Error: declaration expected, not `"Jan 10 2019"`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=7524

#line 47 __DATE__
