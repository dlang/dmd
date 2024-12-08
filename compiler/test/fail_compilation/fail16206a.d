/*
TEST_OUTPUT:
---
fail_compilation/fail16206a.d(16): Error: `bool` expected as third argument of `__traits(getOverloads)`, not `"Not a bool"` of type `string`
alias allFoos = AliasSeq!(__traits(getOverloads, S, "foo", "Not a bool"));
                          ^
---
*/

struct S
{
    static int foo()() { return 0; }
}

alias AliasSeq(T...) = T;
alias allFoos = AliasSeq!(__traits(getOverloads, S, "foo", "Not a bool"));
