/*
TEST_OUTPUT:
---
fail_compilation/diag8510.d(10): Error: alias diag8510.a conflicts with alias diag8510.a at fail_compilation/diag8510.d(9)
fail_compilation/diag8510.d(18): Error: alias diag8510.S.a conflicts with alias diag8510.S.a at fail_compilation/diag8510.d(17)
---
*/

alias int a;
alias long a;

int g;
int h;

struct S
{
    alias g a;
    alias h a;
}
