// REQUIRED_ARGS: -o-
/*
TEST_OUTPUT:
---
fail_compilation/ice13497.d(13): Error: array operation a[] * a[] without assignment not implemented
fail_compilation/ice13497.d(16): Error: invalid array operation c = a[] * a[] (did you forget a [] ?)
---
*/

void main()
{
    int[1] a;
    auto b = (a[] * a[])[];

    int[] c;
    c = (a[] * a[])[];
}
