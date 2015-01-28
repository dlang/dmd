/*
TEST_OUTPUT:
---
fail_compilation/fail481.d(15): Error: mismatch length 2 and 3
fail_compilation/fail481.d(17): Error: mismatch type int[2] and int[3]
fail_compilation/fail481.d(20): Error: cannot match auto[] and void delegate()
fail_compilation/fail481.d(22): Error: undefined identifier __dollar
fail_compilation/fail481.d(23): Error: undefined identifier __dollar
fail_compilation/fail481.d(24): Error: cannot match int[__dollar] and int
---
*/

void main()
{
    auto[2] a1 = [1,2,3];

    auto[$][$] a2 = [[1,2],[3,4,5]];

    void delegate() dg;
    auto[] ar = dg;

    int[$] a3;
    int[$] a4 = void;
    int[$] a5 = 1;
}
