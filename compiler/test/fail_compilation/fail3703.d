// https://issues.dlang.org/show_bug.cgi?id=3703
// static array assignment
/*
TEST_OUTPUT:
---
fail_compilation/fail3703.d(30): Error: mismatched array lengths 2 and 1 for assignment `b[] = a`
    int[2] b = a;   // should make compile error
           ^
fail_compilation/fail3703.d(32): Error: mismatched array lengths 2 and 1 for assignment `b[] = a`
    b = a;  // should make compile error
      ^
fail_compilation/fail3703.d(34): Error: mismatched array lengths, 3 and 2
    int[3] sa3 = [1,2][];
           ^
fail_compilation/fail3703.d(35): Error: mismatched array lengths, 2 and 3
    int[2] sa2 = sa3[][];
           ^
fail_compilation/fail3703.d(37): Error: mismatched array lengths, 3 and 2
    sa3 = [1,2][];
        ^
fail_compilation/fail3703.d(38): Error: mismatched array lengths, 2 and 3
    sa2 = sa3[][];
        ^
---
*/

void main()
{
    int[1] a = [1];
    int[2] b = a;   // should make compile error

    b = a;  // should make compile error

    int[3] sa3 = [1,2][];
    int[2] sa2 = sa3[][];

    sa3 = [1,2][];
    sa2 = sa3[][];
}
