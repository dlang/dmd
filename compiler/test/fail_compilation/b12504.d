/*
TEST_OUTPUT:
---
fail_compilation/b12504.d(58): Error: cannot implicitly convert expression `257$?:32=u|64=LU$` of type `$?:32=uint|64=ulong$` to `ubyte`
        foreach (ubyte i; 0 .. sta.length) {}
                               ^
fail_compilation/b12504.d(59): Error: index type `ubyte` cannot cover index range 0..257
        foreach (ubyte i, x; sta) {}
        ^
fail_compilation/b12504.d(63): Error: cannot implicitly convert expression `129$?:32=u|64=LU$` of type `$?:32=uint|64=ulong$` to `byte`
        foreach (byte i; 0 .. sta.length) {}
                              ^
fail_compilation/b12504.d(64): Error: index type `byte` cannot cover index range 0..129
        foreach (byte i, x; sta) {}
        ^
fail_compilation/b12504.d(68): Error: cannot implicitly convert expression `65537$?:32=u|64=LU$` of type `$?:32=uint|64=ulong$` to `ushort`
        foreach (ushort i; 0 .. sta.length) {}
                                ^
fail_compilation/b12504.d(69): Error: index type `ushort` cannot cover index range 0..65537
        foreach (ushort i, x; sta) {}
        ^
fail_compilation/b12504.d(73): Error: cannot implicitly convert expression `32769$?:32=u|64=LU$` of type `$?:32=uint|64=ulong$` to `short`
        foreach (short i; 0 .. sta.length) {}
                               ^
fail_compilation/b12504.d(74): Error: index type `short` cannot cover index range 0..32769
        foreach (short i, x; sta) {}
        ^
fail_compilation/b12504.d(78): Error: cannot implicitly convert expression `257$?:32=u|64=LU$` of type `$?:32=uint|64=ulong$` to `ubyte`
        static foreach (ubyte i; 0 .. sta.length) {}
                                      ^
fail_compilation/b12504.d(79): Error: index type `ubyte` cannot cover index range 0..257
        static foreach (ubyte i, x; sta) {}
                                    ^
fail_compilation/b12504.d(83): Error: cannot implicitly convert expression `129$?:32=u|64=LU$` of type `$?:32=uint|64=ulong$` to `byte`
        static foreach (byte i; 0 .. sta.length) {}
                                     ^
fail_compilation/b12504.d(84): Error: index type `byte` cannot cover index range 0..129
        static foreach (byte i, x; sta) {}
                                   ^
fail_compilation/b12504.d(88): Error: cannot implicitly convert expression `65537$?:32=u|64=LU$` of type `$?:32=uint|64=ulong$` to `ushort`
        static foreach (ushort i; 0 .. sta.length) {}
                                       ^
fail_compilation/b12504.d(89): Error: index type `ushort` cannot cover index range 0..65537
        static foreach (ushort i, x; sta) {}
                                     ^
fail_compilation/b12504.d(93): Error: cannot implicitly convert expression `32769$?:32=u|64=LU$` of type `$?:32=uint|64=ulong$` to `short`
        static foreach (short i; 0 .. sta.length) {}
                                      ^
fail_compilation/b12504.d(94): Error: index type `short` cannot cover index range 0..32769
        static foreach (short i, x; sta) {}
                                    ^
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
    {
        immutable int[0xFF + 2] sta;
        static foreach (ubyte i; 0 .. sta.length) {}
        static foreach (ubyte i, x; sta) {}
    }
    {
        immutable int[0x7F + 2] sta;
        static foreach (byte i; 0 .. sta.length) {}
        static foreach (byte i, x; sta) {}
    }
    {
        immutable int[0xFFFF + 2] sta;
        static foreach (ushort i; 0 .. sta.length) {}
        static foreach (ushort i, x; sta) {}
    }
    {
        immutable int[0x7FFF + 2] sta;
        static foreach (short i; 0 .. sta.length) {}
        static foreach (short i, x; sta) {}
    }
}
