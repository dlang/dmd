// PERMUTE_ARGS:

/*
TEST_OUTPUT:
---
fail_compilation/deprecate12979d.d(12): Error: asm block is not @trusted or @safe
---
*/

void foo() @safe
{
    asm
    {
        ret;
    }
}
