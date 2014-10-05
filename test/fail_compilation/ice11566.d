/*
TEST_OUTPUT:
---
fail_compilation/ice11566.d(11): Error: invalid array operation a[] <<= 1 (possible missing [])
---
*/

void main()
{
    int[] a;
    a[] <<= 1;
}
