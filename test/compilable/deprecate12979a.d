// REQUIRED_ARGS: -dw
// PERMUTE_ARGS:

/*
TEST_OUTPUT:
---
compilable/deprecate12979a.d(13): Deprecation: asm block is not nothrow
---
*/

void foo() nothrow
{
    asm
    {
        ret;
    }
}
