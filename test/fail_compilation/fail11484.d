/*
REQUIRED_ARGS: -o-
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/fail11484.d(19): Error: cannot cast expression [nanF] of type float[1] to int
fail_compilation/fail11484.d(20): Error: cannot cast expression [0] of type int[1] to int
fail_compilation/fail11484.d(21): Error: cannot cast expression 0 of type int to int[1]
fail_compilation/fail11484.d(22): Error: cannot cast expression 0 of type int to float[1]
fail_compilation/fail11484.d(23): Error: cannot cast expression null of type float[] to int
fail_compilation/fail11484.d(24): Error: cannot cast expression null of type int[] to int
fail_compilation/fail11484.d(25): Error: cannot cast expression 0 of type int to int[]
fail_compilation/fail11484.d(26): Error: cannot cast expression 0 of type int to float[]
---
*/

void main()
{
    cast(void)cast(int)(float[1]).init;
    cast(void)cast(int)(int[1]).init;
    cast(void)cast(int[1])(int).init;
    cast(void)cast(float[1])(int).init;
    cast(void)cast(int)(float[]).init;
    cast(void)cast(int)(int[]).init;
    cast(void)cast(int[])(int).init;
    cast(void)cast(float[])(int).init;
}
