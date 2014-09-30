// REQUIRED_ARGS: -o-
/*
TEST_OUTPUT:
---
fail_compilation/ice13497.d(15): Error: array operation a[] * a[] without assignment not implemented
fail_compilation/ice13497.d(16): Error: array operation (a[] * a[])[0..1] without assignment not implemented
fail_compilation/ice13497.d(19): Error: array operation a[] * a[] without assignment not implemented
fail_compilation/ice13497.d(20): Error: array operation (a[] * a[])[0..1] without assignment not implemented
---
*/

void test13497()
{
    int[1] a;
    auto b1 = (a[] * a[])[];
    auto b2 = (a[] * a[])[0..1];

    int[] c;
    c = (a[] * a[])[];
    c = (a[] * a[])[0..1];
}

/*
TEST_OUTPUT:
---
fail_compilation/ice13497.d(34): Error: array operation h * y[] without assignment not implemented
---
*/
void test12381()
{
    double[2] y;
    double h;

    double[2] temp1 = cast(double[2])(h * y[]);
}
