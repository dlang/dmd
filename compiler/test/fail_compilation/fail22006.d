/*
TEST_OUTPUT:
---
fail_compilation/fail22006.d(17): Error: implicit conversion from `ulong` (64 bytes) to `bool` (8 bytes) may truncate value
fail_compilation/fail22006.d(17):        Use an explicit cast (e.g., `cast(bool)expr`) to silence this.
fail_compilation/fail22006.d(18): Error: index type `bool` cannot cover index range 0..4
fail_compilation/fail22006.d(21): Error: implicit conversion from `ulong` (64 bytes) to `bool` (8 bytes) may truncate value
fail_compilation/fail22006.d(21):        Use an explicit cast (e.g., `cast(bool)expr`) to silence this.
fail_compilation/fail22006.d(22): Error: index type `bool` cannot cover index range 0..4
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
