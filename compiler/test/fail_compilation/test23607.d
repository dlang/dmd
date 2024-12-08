//https://issues.dlang.org/show_bug.cgi?id=23607
/*
TEST_OUTPUT:
---
fail_compilation/test23607.d(19): Error: template `to(T)()` does not have property `bad`
alias comb = to!int.bad!0;
             ^
fail_compilation/test23607.d(20): Error: template `to(T)()` does not have property `bad`
auto combe = to!int.bad!0;
                   ^
---
*/

template to(T)
{
    void to(T)(){}
}

alias comb = to!int.bad!0;
auto combe = to!int.bad!0;
