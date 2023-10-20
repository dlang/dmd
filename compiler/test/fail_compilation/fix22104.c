/* TEST_OUTPUT:
---
fail_compilation/fix22104.c(103): Error: variable `fix22104.test1.array1` - incomplete array type must have initializer
fail_compilation/fix22104.c(108): Error: variable `fix22104.test2.array2` - incomplete array type must have initializer
---
 */

// https://issues.dlang.org/show_bug.cgi?id=22104

#line 100

void test1()
{
    static int array1[][4];
}

void test2()
{
    int array2[][4];
}
