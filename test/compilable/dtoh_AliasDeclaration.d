// REQUIRED_ARGS: -HCf=${RESULTS_DIR}/compilable/dtoh_AliasDeclaration.h -c
// PERMUTE_ARGS:
// POST_SCRIPT: compilable/extra-files/dtoh-postscript.sh

/*
TEST_OUTPUT:
---
---
*/

alias T = int;

extern (C) int x;

alias u = x;

extern (C) int foo(int x)
{
    return x * 42;
}

alias fun = foo;

extern (C++) int foo2(int x)
{
    return x * 42;
}

alias fun2 = foo2;

extern (C) struct S;

alias aliasS = S;

extern (C++) struct S2;

alias aliasS2 = S2;

extern (C) class C;

alias aliasC = C;

extern (C++) class C2;

alias aliasC2 = C2;
