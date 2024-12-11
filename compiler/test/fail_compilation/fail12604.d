/*
TEST_OUTPUT:
---
fail_compilation/fail12604.d(68): Error: mismatched array lengths, 1 and 3
      int[1] a1 = [1,2,3];
             ^
fail_compilation/fail12604.d(69): Error: mismatched array lengths, 1 and 3
    short[1] a2 = [1,2,3];
             ^
fail_compilation/fail12604.d(71): Error: mismatched array lengths, 1 and 3
      int[1] b1; b1 = [1,2,3];
                    ^
fail_compilation/fail12604.d(72): Error: mismatched array lengths, 1 and 3
    short[1] b2; b2 = [1,2,3];
                    ^
fail_compilation/fail12604.d(74): Error: cannot implicitly convert expression `[65536]` of type `int[]` to `short[]`
    short[1] c = [65536];
                 ^
fail_compilation/fail12604.d(75): Error: cannot implicitly convert expression `[65536, 2, 3]` of type `int[]` to `short[]`
    short[1] d = [65536,2,3];
                 ^
fail_compilation/fail12604.d(80): Error: mismatched array lengths, 2 and 3
      uint[2] a1 = [1, 2, 3][];
              ^
fail_compilation/fail12604.d(81): Error: mismatched array lengths, 2 and 3
    ushort[2] a2 = [1, 2, 3][];
              ^
fail_compilation/fail12604.d(82): Error: mismatched array lengths, 2 and 3
      uint[2] a3 = [1, 2, 3][0 .. 3];
              ^
fail_compilation/fail12604.d(83): Error: mismatched array lengths, 2 and 3
    ushort[2] a4 = [1, 2, 3][0 .. 3];
              ^
fail_compilation/fail12604.d(84): Error: mismatched array lengths, 2 and 3
    a1 = [1, 2, 3][];
       ^
fail_compilation/fail12604.d(85): Error: mismatched array lengths, 2 and 3
    a2 = [1, 2, 3][];
       ^
fail_compilation/fail12604.d(86): Error: mismatched array lengths, 2 and 3
    a3 = [1, 2, 3][0 .. 3];
       ^
fail_compilation/fail12604.d(87): Error: mismatched array lengths, 2 and 3
    a4 = [1, 2, 3][0 .. 3];
       ^
fail_compilation/fail12604.d(92): Error: mismatched array lengths, 2 and 3
    static   uint[2] a1 = [1, 2, 3][];
                          ^
fail_compilation/fail12604.d(93): Error: mismatched array lengths, 2 and 3
    static   uint[2] a2 = [1, 2, 3][0 .. 3];
                          ^
fail_compilation/fail12604.d(94): Error: mismatched array lengths, 2 and 3
    static ushort[2] a3 = [1, 2, 3][];
                          ^
fail_compilation/fail12604.d(95): Error: mismatched array lengths, 2 and 3
    static ushort[2] a4 = [1, 2, 3][0 .. 3];
                          ^
fail_compilation/fail12604.d(102): Error: mismatched array lengths 4 and 3 for assignment `sa1[0..4] = [1, 2, 3]`
    sa1[0..4] = [1,2,3];
              ^
fail_compilation/fail12604.d(103): Error: mismatched array lengths 4 and 3 for assignment `sa1[0..4] = sa2`
    sa1[0..4] = sa2;
              ^
---
*/
void main()
{
      int[1] a1 = [1,2,3];
    short[1] a2 = [1,2,3];

      int[1] b1; b1 = [1,2,3];
    short[1] b2; b2 = [1,2,3];

    short[1] c = [65536];
    short[1] d = [65536,2,3];
}

void test12606a()   // AssignExp::semantic
{
      uint[2] a1 = [1, 2, 3][];
    ushort[2] a2 = [1, 2, 3][];
      uint[2] a3 = [1, 2, 3][0 .. 3];
    ushort[2] a4 = [1, 2, 3][0 .. 3];
    a1 = [1, 2, 3][];
    a2 = [1, 2, 3][];
    a3 = [1, 2, 3][0 .. 3];
    a4 = [1, 2, 3][0 .. 3];
}

void test12606b()   // ExpInitializer::semantic
{
    static   uint[2] a1 = [1, 2, 3][];
    static   uint[2] a2 = [1, 2, 3][0 .. 3];
    static ushort[2] a3 = [1, 2, 3][];
    static ushort[2] a4 = [1, 2, 3][0 .. 3];
}

void testc()
{
    int[4] sa1;
    int[3] sa2;
    sa1[0..4] = [1,2,3];
    sa1[0..4] = sa2;
}
