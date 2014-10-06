
version (D_InlineAsm_X86)
    version = TestInlineAsm;
else version (D_InlineAsm_X86_64)
    version = TestInlineAsm;
else
    pragma(msg, "Inline asm not supported, not testing.");

version (TestInlineAsm)
{
    void testInlineAsm()
    {
        asm
        {
            naked;

            // static if - brackets
            static if (1 != 0)
                mov EAX, ECX;

            mov EDX, ECX;

            // static if - brackets + else
            static if (3 == 3)
                add EAX, 0x03;
            else
                mov EDX, EAX;

            // static if + brackets
            static if (0 == 1)
            {
                mov EAX, ECX;
            }

            nop;

            // static if + brackets + else
            static if (4 == 2)
            {
                add EAX, 0x0548;
            }
            else
            {
                sub EAX, 0x0548;
            }

            // Note that this needs to be 
            // the last block in the asm
            // block in order to test for
            // a specific regression.

            // chained static if
            static if (3 < 2)
                nop;
            else static if (5 > 3)
                nop;
            else
                ret 3;
        }

        asm
        {
            nop;
            version (D_InlineAsm_X86_64)
                push RBP;

            version (D_InlineAsm_X86)
                push ESP;
            else
                push RBP;

            version (D_HardFloat)
            {
                finit;
                fadd ST, ST(1);
            }

            // Take for example a 128-bit mem->mem
            // copy operation.
            version (D_SIMD)
            {
                movdqa XMM1, [ESP + 16];
                movdqa [EBP + 16], XMM1;
            }
            else version(D_InlineAsm_X86_64)
            {
                mov RAX, [ESP + 8];
                mov [EBP + 8], RAX;
                mov RAX, [ESP + 16];
                mov [EBP + 16], RAX;
            }
            else
            {
                mov EAX, [ESP + 4];
                mov [EBP + 4], EAX;
                mov EAX, [ESP + 8];
                mov [EBP + 8], EAX;
                mov EAX, [ESP + 12];
                mov [EBP + 12], EAX;
                mov EAX, [ESP + 16];
                mov [EBP + 16], EAX;
            }

            debug (1)
                nop;

            debug (2)
            {
                nop;
            }

            debug (3)
                nop;
            else
                mov EAX, ECX;

            debug (4)
            {
                mov EAX, ECX;
            }
            else debug (5)
            {
                mov EAX, EBX;
            }
            else
            {
                mov EAX, EDX;
            }
        }
    }
}
