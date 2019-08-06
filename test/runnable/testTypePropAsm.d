module testTypePropAsm;

alias Seq(T...) = T;

version(D_InlineAsm_X86_64)
{
    T testMax(T)()
    {
        enum code = "asm
        {
            naked;
            mov RAX, " ~ T.stringof ~ ".max;
            ret;
        }";
        mixin(code);
    }

    T testAlignOf(T)()
    {
        enum code = "asm
        {
            naked;
            mov RAX, " ~ T.stringof ~ ".alignof;
            ret;
        }";
        mixin(code);
    }

    alias IntTypes = Seq!(bool, ubyte, ushort, uint, ulong, byte, short, int, long, char, wchar, dchar);

    void main()
    {
        static foreach (T; IntTypes)
        {
            assert(testMax!T == T.max);
            assert(testAlignOf!T == T.alignof);
        }
    }
}
else
{
    void main(){}
}
