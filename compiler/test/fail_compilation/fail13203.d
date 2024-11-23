int v1, v2;

/*
TEST_OUTPUT:
---
fail_compilation/fail13203.d(35): Error: alias `fail13203.FA1!1.T` conflicts with alias `fail13203.FA1!1.T` at fail_compilation/fail13203.d(34)
    static if (b) alias T = uint;
                  ^
fail_compilation/fail13203.d(42): Error: template instance `fail13203.FA1!1` error instantiating
alias A1 = FA1!1;   // type is not overloadable
           ^
fail_compilation/fail13203.d(40): Error: alias `fail13203.FA2!1.T` conflicts with alias `fail13203.FA2!1.T` at fail_compilation/fail13203.d(39)
    static if (b) alias T = v2;
                  ^
fail_compilation/fail13203.d(43): Error: template instance `fail13203.FA2!1` error instantiating
alias A2 = FA2!1;   // variable symbol is not overloadable
           ^
fail_compilation/fail13203.d(47): Error: alias `fail13203.FB1!1.T` conflicts with alias `fail13203.FB1!1.T` at fail_compilation/fail13203.d(48)
    static if (b) alias T = uint;
                  ^
fail_compilation/fail13203.d(55): Error: template instance `fail13203.FB1!1` error instantiating
alias B1 = FB1!1;
           ^
fail_compilation/fail13203.d(52): Error: alias `fail13203.FB2!1.T` conflicts with alias `fail13203.FB2!1.T` at fail_compilation/fail13203.d(53)
    static if (b) alias T = v2;
                  ^
fail_compilation/fail13203.d(56): Error: template instance `fail13203.FB2!1` error instantiating
alias B2 = FB2!1;
           ^
---
*/
template FA1(int b)
{
    alias T = int;
    static if (b) alias T = uint;
}
template FA2(int b)
{
    alias T = v1;
    static if (b) alias T = v2;
}
alias A1 = FA1!1;   // type is not overloadable
alias A2 = FA2!1;   // variable symbol is not overloadable

template FB1(int b)
{
    static if (b) alias T = uint;
    alias T = int;
}
template FB2(int b)
{
    static if (b) alias T = v2;
    alias T = v1;
}
alias B1 = FB1!1;
alias B2 = FB2!1;
