/*
TEST_OUTPUT:
---
fail_compilation/fail22006.d(23): Error: cannot implicitly convert expression `4$?:32=u|64=LU$` of type `$?:32=uint|64=ulong$` to `bool`
        static foreach (bool i; 0 .. aseq.length) {}
                                         ^
fail_compilation/fail22006.d(24): Error: index type `bool` cannot cover index range 0..4
        static foreach (bool i, x; aseq) {}
        ^
fail_compilation/fail22006.d(27): Error: cannot implicitly convert expression `4$?:32=u|64=LU$` of type `$?:32=uint|64=ulong$` to `bool`
        static foreach (bool i; 0 .. [0, 1, 2, 3].length) {}
                                     ^
fail_compilation/fail22006.d(28): Error: index type `bool` cannot cover index range 0..4
        static foreach (bool i, x; [0, 1, 2, 3]) {}
        ^
---
*/
void test22006()
{
    alias AliasSeq(TList...) = TList;
    {
        alias aseq = AliasSeq!(0, 1, 2, 3);
        static foreach (bool i; 0 .. aseq.length) {}
        static foreach (bool i, x; aseq) {}
    }
    {
        static foreach (bool i; 0 .. [0, 1, 2, 3].length) {}
        static foreach (bool i, x; [0, 1, 2, 3]) {}
    }
}
