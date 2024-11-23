/*
TEST_OUTPUT:
---
fail_compilation/fail312.d(17): Error: incompatible types for `(a[]) == (b)`: `int[]` and `short`
    assert(a[] == b);
           ^
fail_compilation/fail312.d(18): Error: incompatible types for `(a[]) <= (b)`: `int[]` and `short`
    assert(a[] <= b);
           ^
---
*/

void main()
{
    int[1] a = 1;
    short b = 1;
    assert(a[] == b);
    assert(a[] <= b);
}
