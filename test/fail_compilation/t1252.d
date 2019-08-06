/*
TEST_OUTPUT:
---
fail_compilation/t1252.d(20): Error: property of basic type `int` expected
---
*/
module t1252;

version(D_InlineAsm_X86)
    version = doTest;
else version(D_InlineAsm_X86_64)
    version = doTest;

version(doTest)
{
    void main()
    {
        asm
        {
            mov EAX, int.;
        }
    }
}
// still need to fail compilation !
else static assert(false);

