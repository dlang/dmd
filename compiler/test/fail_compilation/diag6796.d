/*
TEST_OUTPUT:
---
fail_compilation/diag6796.d(15): Error: cannot implicitly convert expression `0` of type `int` to `int[]`
    enum int[][] array = [0, 1];
                          ^
fail_compilation/diag6796.d(15): Error: cannot implicitly convert expression `1` of type `int` to `int[]`
    enum int[][] array = [0, 1];
                             ^
---
*/

void main()
{
    enum int[][] array = [0, 1];
    array[0] *= 10;
}
