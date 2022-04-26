/*
TEST_OUTPUT:
---
fail_compilation/test22070.c(10): Error: `&""` is not an lvalue and cannot be modified
---
*/

// https://issues.dlang.org/show_bug.cgi?id=22070

char(**s1)[3] = &(&"");
