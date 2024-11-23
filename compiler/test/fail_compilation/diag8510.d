/*
TEST_OUTPUT:
---
fail_compilation/diag8510.d(14): Error: alias `diag8510.a` conflicts with alias `diag8510.a` at fail_compilation/diag8510.d(13)
alias int a;
^
fail_compilation/diag8510.d(19): Error: alias `diag8510.S.a` conflicts with alias `diag8510.S.a` at fail_compilation/diag8510.d(18)
    alias g a;
    ^
---
*/

alias int a;
alias int a;

int g;
struct S {
    alias g a;
    alias g a;
}
