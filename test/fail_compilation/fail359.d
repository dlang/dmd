/*
TEST_OUTPUT:
---
fail_compilation/fail359.d(7): Error: #line integer ["filespec"]\n expected
---
*/
#line 5 _BOOM
void main() { }
