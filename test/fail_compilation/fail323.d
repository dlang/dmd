/*
TEST_OUTPUT:
---
fail_compilation/fail323.d(16): Error: invalid array operation -a (possible missing [])
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
