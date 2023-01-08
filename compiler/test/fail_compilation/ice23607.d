//https://issues.dlang.org/show_bug.cgi?id=23607
/*
TEST_OUTPUT:
---
fail_compilation/ice23607.d(14): Error: template identifier `bad` is not a member of template `ice23607.to!int.to(T)()`
---
*/

template to(T)
{
    void to(T)(){}
}

alias comb = to!int.bad!0;
