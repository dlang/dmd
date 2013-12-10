/*
TEST_OUTPUT:
---
fail_compilation/fail323.d(16): Error: 'a' is not of arithmetic type, it is a double[]
---
*/

void foo(double[]) { }

void main()
{
    auto a = new double[10],
         b = a.dup,
         c = a.dup,
         d = a.dup;
    foo(-a);
    // a[] = -(b[] * (c[] + 4)) + 5 * d[]; // / 3;
}
