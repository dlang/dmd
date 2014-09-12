/*
TEST_OUTPUT:
---
fail_compilation/fail13382.d(18): Error: incompatible types for ((sn = sn) > (0)): 'int[]' and 'int'
fail_compilation/fail13382.d(19): Error: incompatible types for ((sn = sn) >= (0)): 'int[]' and 'int'
fail_compilation/fail13382.d(20): Error: incompatible types for ((sn = sn) < (0)): 'int[]' and 'int'
fail_compilation/fail13382.d(21): Error: incompatible types for ((sn = sn) <= (0)): 'int[]' and 'int'
fail_compilation/fail13382.d(22): Error: incompatible types for ((sn = sn) == (0)): 'int[]' and 'int'
fail_compilation/fail13382.d(23): Error: incompatible types for ((sn = sn) != (0)): 'int[]' and 'int'
fail_compilation/fail13382.d(24): Error: incompatible types for ((sn = sn) is (0)): 'int[]' and 'int'
fail_compilation/fail13382.d(25): Error: incompatible types for ((sn = sn) !is (0)): 'int[]' and 'int'
---
*/

void main ()
{
    int[] sn;
    if ((sn = sn) > 0) {}
    if ((sn = sn) >= 0) {}
    if ((sn = sn) < 0) {}
    if ((sn = sn) <= 0) {}
    if ((sn = sn) == 0) {}
    if ((sn = sn) != 0) {}
    if ((sn = sn) is 0) {}
    if ((sn = sn) !is 0) {}
}
