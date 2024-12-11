// REQUIRED_ARGS: -de

/*
TEST_OUTPUT:
---
fail_compilation/deprecate12979c.d(14): Error: `asm` statement is assumed to use the GC - mark it with `@nogc` if it does not
    asm
    ^
---
*/

void foo() @nogc
{
    asm
    {
        ret;
    }
}
