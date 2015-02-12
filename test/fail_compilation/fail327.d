/*
TEST_OUTPUT:
---
fail_compilation/fail327.d(10): Error: asm statement is assumed to be @system - mark it with '@trusted' if it is not
---
*/

@safe void foo()
{
    asm { xor EAX,EAX; }
}
