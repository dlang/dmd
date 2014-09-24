// REQUIRED_ARGS: -w
/*
TEST_OUTPUT:
---
fail_compilation/diag_cstyle.d(14): Deprecation: C-style syntax is deprecated. Please use 'int function(int) fp1' instead
fail_compilation/diag_cstyle.d(15): Deprecation: C-style syntax is deprecated. Please use 'int function(int)* fp3' instead
fail_compilation/diag_cstyle.d(17): Deprecation: C-style syntax is deprecated. Please use 'int function(int) FP' instead
fail_compilation/diag_cstyle.d(19): Deprecation: C-style syntax is deprecated. Please use 'int function() fp' instead
fail_compilation/diag_cstyle.d(19): Warning: instead of C-style syntax, use D-style syntax 'int[] arr'
fail_compilation/diag_cstyle.d(21): Warning: instead of C-style syntax, use D-style syntax 'string[] result'
---
*/

int (*fp1)(int);
int (*(*fp3))(int);

alias int(*FP)(int);

void foo(int(*fp)(), int arr[]) {}

string result[]() = "abc";
