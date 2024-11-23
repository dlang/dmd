/*
TEST_OUTPUT:
---
fail_compilation/ice13382.d(34): Error: incompatible types for `(a) == (0)`: `int[]` and `int`
    if (a == 0) {}
        ^
fail_compilation/ice13382.d(35): Error: incompatible types for `(a) >= (0)`: `int[]` and `int`
    if (a >= 0) {}
        ^
fail_compilation/ice13382.d(36): Error: incompatible types for `(0) == (a)`: `int` and `int[]`
    if (0 == a) {}
        ^
fail_compilation/ice13382.d(37): Error: incompatible types for `(0) >= (a)`: `int` and `int[]`
    if (0 >= a) {}
        ^
fail_compilation/ice13382.d(38): Error: incompatible types for `(a) is (0)`: `int[]` and `int`
    if (a  is 0) {}
        ^
fail_compilation/ice13382.d(39): Error: incompatible types for `(a) !is (0)`: `int[]` and `int`
    if (a !is 0) {}
        ^
fail_compilation/ice13382.d(40): Error: incompatible types for `(0) is (a)`: `int` and `int[]`
    if (0  is a) {}
        ^
fail_compilation/ice13382.d(41): Error: incompatible types for `(0) !is (a)`: `int` and `int[]`
    if (0 !is a) {}
        ^
---
*/

void main ()
{
    int[] a;
    if (a == 0) {}
    if (a >= 0) {}
    if (0 == a) {}
    if (0 >= a) {}
    if (a  is 0) {}
    if (a !is 0) {}
    if (0  is a) {}
    if (0 !is a) {}
}
