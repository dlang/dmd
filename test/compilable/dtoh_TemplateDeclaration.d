// REQUIRED_ARGS: -HCf=${RESULTS_DIR}/compilable/dtoh_TemplateDeclaration.out -c
// PERMUTE_ARGS:
// POST_SCRIPT: compilable/extra-files/dtoh-postscript.sh

/*
TEST_OUTPUT:
---
---
*/

extern (C++) struct A(T)
{
    T x;
    // enum Num = 42; // dtoh segfaults at enum

    void foo() {}
}

extern (C++) struct B
{
    A!int x;
}
