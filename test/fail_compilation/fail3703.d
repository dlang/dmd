// Issue 3703 - static array assignment

/*
TEST_OUTPUT:
---
fail_compilation/fail3703.d(15): Error: mismatched array lengths, 2 and 1
---
*/

void main()
{
    int[1] a = [1];
    int[2] b;

    b = a;  // should make compile error
}
