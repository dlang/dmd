/*
TEST_OUTPUT:
---
fail_compilation/fail327.d(10): Error: asm block is not @trusted or @safe
---
*/

@safe void foo()
{
    asm { xor EAX,EAX; }
}
