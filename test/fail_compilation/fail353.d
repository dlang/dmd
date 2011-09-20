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
        loop L1; // signed underflow of rel8
    }
}
