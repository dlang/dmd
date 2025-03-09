
/*
TEST_OUTPUT:
---
fail_compilation/deprecate12979d.d(11): Error: executing an `asm` statement without `@trusted` annotation is not allowed in a `@safe` function
---
*/

void foo() @safe
{
    asm
    {
        ret;
    }
}
