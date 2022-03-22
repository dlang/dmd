// https://issues.dlang.org/show_bug.cgi?id=22825
/* TEST_OUTPUT:
---
fail_compilation/fail22825a.d(8): Error: #line integer ["filespec"]\n expected
fail_compilation/fail22825a.d(11): Error: declaration expected, not `42`
---
*/
#line /*
         multi-line comment
*/
42
