/*
TEST_OUTPUT:
---
fail_compilation/fail3354.d(16): Error: 4 operands found for `fldz` instead of the expected 0
fail_compilation/fail3354.d(17): Error: 4 operands found for `fld` instead of the expected 1
---
*/

void main()
{
    version(D_InlineAsm_X86) {}
    else version(D_InlineAsm_X86_64) {}
    else static assert(0);

    asm {
        fldz ST(0), ST(1), ST(2), ST(3);
        fld ST(0), ST(1), ST(2), ST(3);
    }
}
