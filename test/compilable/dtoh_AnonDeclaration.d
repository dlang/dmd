// REQUIRED_ARGS: -HCf=${RESULTS_DIR}/compilable/dtoh_AnonDeclaration.out -c
// PERMUTE_ARGS:
// POST_SCRIPT: compilable/extra-files/dtoh-postscript.sh

/*
TEST_OUTPUT:
---
---
*/

extern (C++) struct S
{
    union
    {
        int x;
        char[4] c;
    }

    struct
    {
        int y;
        double z;
        extern(C) void foo() {}
        extern(C++) void bar() {}
    }
}
