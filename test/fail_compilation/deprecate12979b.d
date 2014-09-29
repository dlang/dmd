// REQUIRED_ARGS: -de
// PERMUTE_ARGS:

/*
TEST_OUTPUT:
---
fail_compilation/deprecate12979b.d(13): Deprecation: asm block is not pure
---
*/

void foo() pure
{
    asm
    {
        ret;
    }
}
