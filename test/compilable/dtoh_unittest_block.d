// REQUIRED_ARGS: -HCf=${RESULTS_DIR}/compilable/dtoh_unittest_block.h -c
// PERMUTE_ARGS:
// POST_SCRIPT: compilable/extra-files/dtoh-postscript.sh

/*
TEST_OUTPUT:
---
---
*/

unittest
{
    extern (C++) int foo(int x)
    {
        return x * 42;
    }
}
