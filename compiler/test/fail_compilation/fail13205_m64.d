// REQUIRED_ARGS: -m64
/*
TEST_OUTPUT:
---
fail_compilation/fail13205_m64.d(14): Error: mismatched array lengths 8 and 9 for assignment `b[] = a[cast(ulong)j..cast(ulong)(j + 9)]`
---
*/

void main()
{
    int[100] a;
    int[8] b;
    int j = 20;
    b[] = a[j .. j + 9];
}
