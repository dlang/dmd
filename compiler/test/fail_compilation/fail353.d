/*
TEST_OUTPUT:
---
block displacement of -130 exceeds the maximum offset of -128 to 127.
---
*/

void foo()
{
    enum NOP = 0x9090_9090_9090_9090;

    asm
    {
    L1:
        dq NOP,NOP,NOP,NOP;    //  32
        dq NOP,NOP,NOP,NOP;    //  64
        dq NOP,NOP,NOP,NOP;    //  96
        dq NOP,NOP,NOP,NOP;    // 128
        // unnoticed signed underflow of rel8 with DMD2.056
        loop L1;
    }
}
