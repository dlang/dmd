/*
TEST_OUTPUT:
---
fail_compilation/diag_cstyle.d(25): Error: instead of C-style syntax, use D-style `int function(int) fp1`
int (*fp1)(int);
    ^
fail_compilation/diag_cstyle.d(26): Error: instead of C-style syntax, use D-style `int function(int)* fp3`
int (*(*fp3))(int);
    ^
fail_compilation/diag_cstyle.d(28): Error: instead of C-style syntax, use D-style `int function(int) FP`
alias int(*FP)(int);
         ^
fail_compilation/diag_cstyle.d(30): Error: instead of C-style syntax, use D-style `int function() fp`
void foo(int(*fp)(), int arr[]) {}
         ^
fail_compilation/diag_cstyle.d(30): Error: instead of C-style syntax, use D-style `int[] arr`
void foo(int(*fp)(), int arr[]) {}
                     ^
fail_compilation/diag_cstyle.d(32): Error: instead of C-style syntax, use D-style `string[] result`
string result[]() = "abc";
       ^
---
*/

int (*fp1)(int);
int (*(*fp3))(int);

alias int(*FP)(int);

void foo(int(*fp)(), int arr[]) {}

string result[]() = "abc";
