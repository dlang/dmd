// REQUIRED_ARGS: -de
// PERMUTE_ARGS:

/*
TEST_OUTPUT:
---
fail_compilation/deprecate12979c.d(13): Deprecation: asm block is not @nogc
---
*/

void foo() @nogc
{
    asm
    {
        ret;
    }
}
