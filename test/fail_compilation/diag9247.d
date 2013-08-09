/*
TEST_OUTPUT:
---
fail_compilation/diag9247.d(11): Error: cannot return opaque struct S by value
fail_compilation/diag9247.d(12): Error: cannot return opaque struct S by value
---
*/

struct S;

S foo();
S function() bar;
