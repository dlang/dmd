/*
TEST_OUTPUT:
---
fail_compilation/ice14272.d(15): Error: circular initialization of variable `ice14272.A14272!1.A14272.tag`
    enum int tag = tag;
                   ^
fail_compilation/ice14272.d(18): Error: template instance `ice14272.A14272!1` error instantiating
alias a14272 = A14272!1;
               ^
---
*/

struct A14272(int tag)
{
    enum int tag = tag;
}

alias a14272 = A14272!1;
