/* TEST_OUTPUT:
---
fail_compilation/goto4.d(8): Error: function `goto4.test` label `L1` is undefined
---
*/


void test()
{
    asm
    {
        jmp L1;
    L2:
        nop;
    }
}
