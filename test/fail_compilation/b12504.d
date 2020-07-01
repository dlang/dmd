/*
TEST_OUTPUT:
---
fail_compilation/b12504.d(18): Error: cannot implicitly convert expression `257$?:32=u|64=LU$` of type `$?:32=uint|64=ulong$` to `ubyte`
fail_compilation/b12504.d(19): Error: index type `ubyte` cannot cover index range 0..257
fail_compilation/b12504.d(23): Error: cannot implicitly convert expression `129$?:32=u|64=LU$` of type `$?:32=uint|64=ulong$` to `byte`
fail_compilation/b12504.d(24): Error: index type `byte` cannot cover index range 0..129
fail_compilation/b12504.d(28): Error: cannot implicitly convert expression `65537$?:32=u|64=LU$` of type `$?:32=uint|64=ulong$` to `ushort`
fail_compilation/b12504.d(29): Error: index type `ushort` cannot cover index range 0..65537
fail_compilation/b12504.d(33): Error: cannot implicitly convert expression `32769$?:32=u|64=LU$` of type `$?:32=uint|64=ulong$` to `short`
fail_compilation/b12504.d(34): Error: index type `short` cannot cover index range 0..32769
---
*/
void main()
{
    {
        int[0xFF + 2] sta;
        foreach (ubyte i; 0 .. sta.length) {}
        foreach (ubyte i, x; sta) {}
    }
    {
        int[0x7F + 2] sta;
        foreach (byte i; 0 .. sta.length) {}
        foreach (byte i, x; sta) {}
    }
    {
        int[0xFFFF + 2] sta;
        foreach (ushort i; 0 .. sta.length) {}
        foreach (ushort i, x; sta) {}
    }
    {
        int[0x7FFF + 2] sta;
        foreach (short i; 0 .. sta.length) {}
        foreach (short i, x; sta) {}
    }
}
