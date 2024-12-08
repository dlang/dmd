/*
TEST_OUTPUT:
---
fail_compilation/fail79.d(15): Error: incompatible types for `(& a) + (& b)`: both operands are of type `int*`
    p = &a + &b;
        ^
---
*/

void main()
{
    int a, b;
    int* p;

    p = &a + &b;
}
