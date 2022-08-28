/*
TEST_OUTPUT:
---
fail_compilation/fail12635.d(13): Error: Cannot generate a segment prefix for a branching instruction
---
*/

void foo()
{
    asm
    {
    L1:
        jmp DS:L1;
    }
}
