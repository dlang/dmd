/* TEST_OUTPUT:
---
fail_compilation/test23058.c(105): Error: array index 4 is out of bounds `[0..3]`
fail_compilation/test23058.c(110): Error: array index 5 is out of bounds `[0..4]`
---
 */

/* https://issues.dlang.org/show_bug.cgi?id=23058
 */

#line 100

int arr[3][4] = { { 1,2,3,4 }, { 5,6,7,8 }, { 9,10,11,12 } };

void test1()
{
    int *p1 = &arr[4][2];
}

void test2()
{
    int *p2 = &arr[2][5];
}
