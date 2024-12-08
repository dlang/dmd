/*
TEST_OUTPUT:
---
fail_compilation/fail24.d(17): Error: alias `fail24.strtype` conflicts with alias `fail24.strtype` at fail_compilation/fail24.d(16)
alias char[64] strtype;
^
fail_compilation/fail24.d(18): Error: alias `fail24.strtype` conflicts with alias `fail24.strtype` at fail_compilation/fail24.d(17)
alias char[128] strtype;
^
fail_compilation/fail24.d(19): Error: alias `fail24.strtype` conflicts with alias `fail24.strtype` at fail_compilation/fail24.d(18)
alias char[256] strtype;
^
---
*/

alias char[]  strtype;
alias char[64] strtype;
alias char[128] strtype;
alias char[256] strtype;

int main()
{
    printf("%u", strtype.sizeof);
    return 0;
}
