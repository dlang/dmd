version (D_InlineAsm_X86_64)
{
    version = InlineAsmX86;
    enum Align = 0x8;
}
else version (D_InlineAsm_X86)
{
    version = InlineAsmX86;
    version (OSX)
        enum Align = 0xC;
}

void onFailure()
{
    assert(0, "alignment failure");
}

void checkAlign()
{
    version (InlineAsmX86)
    {
        static if (is(typeof(Align)))
        asm
        {
            naked;
            mov EAX, ESP;
            and EAX, 0xF;
            cmp EAX, Align;
            je Lpass;
            call onFailure;
        Lpass:
            ret;
        }
    }
    else
        return;
}

void foo()
{
}

void main()
{
    try
        foo();
    finally
        checkAlign();
}
