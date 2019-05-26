// https://issues.dlang.org/show_bug.cgi?id=6795
/*
TEST_OUTPUT:
---
fail_compilation/fail6795.d(12): Error: cannot modify constant `0`
fail_compilation/fail6795.d(13): Error: cannot modify constant `0`
---
*/

void main() {
    enum int[] array = [0];
    array[0]++;
    array[0] += 3;
}

/*
TEST_OUTPUT:
---
fail_compilation/fail6795.d(31): Error: cannot modify constant `0`
fail_compilation/fail6795.d(32): Error: cannot modify constant `0`
fail_compilation/fail6795.d(33): Error: cannot modify constant `0`
---
*/

void test_wrong_line_num()
{
    enum int[] da = [0];
    enum int[1] sa = [0];
    enum int[int] aa = [0:0];

    da[0] += 3;
    sa[0] += 3;
    aa[0] += 3;
}
