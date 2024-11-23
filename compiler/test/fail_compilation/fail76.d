/*
TEST_OUTPUT:
---
fail_compilation/fail76.d(11): Error: alias `fail76.a` conflicts with alias `fail76.a` at fail_compilation/fail76.d(10)
alias void a;
^
---
*/

alias main a;
alias void a;

void main()
{
    a;
}
