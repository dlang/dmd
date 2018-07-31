// REQUIRED_ARGS:
/*
TEST_OUTPUT:
---
fail_compilation/diag_cstyle.d(14): Error: instead of C-style syntax, use D-style `int function(int) fp1`
fail_compilation/diag_cstyle.d(15): Error: instead of C-style syntax, use D-style `int function(int)* fp3`
fail_compilation/diag_cstyle.d(17): Error: instead of C-style syntax, use D-style `int function(int) FP`
fail_compilation/diag_cstyle.d(19): Error: instead of C-style syntax, use D-style `int function() fp`
fail_compilation/diag_cstyle.d(19): Error: instead of C-style syntax, use D-style `int[] arr`
fail_compilation/diag_cstyle.d(21): Error: instead of C-style syntax, use D-style `string[] result`
---
*/

int (*fp1)(int);
int (*(*fp3))(int);

alias int(*FP)(int);

void foo(int(*fp)(), int arr[]) {}

string result[]() = "abc";
