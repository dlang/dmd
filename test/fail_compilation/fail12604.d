/*
TEST_OUTPUT:
---
fail_compilation/fail12604.d(14): Error: mismatched array lengths, 1 and 3
fail_compilation/fail12604.d(15): Error: mismatched array lengths, 1 and 3
fail_compilation/fail12604.d(17): Error: mismatched array lengths, 1 and 3
fail_compilation/fail12604.d(18): Error: mismatched array lengths, 1 and 3
fail_compilation/fail12604.d(20): Error: cannot implicitly convert expression ([65536]) of type int[] to short[]
fail_compilation/fail12604.d(21): Error: cannot implicitly convert expression ([65536, 2, 3]) of type int[] to short[]
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
