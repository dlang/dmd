/*
TEST_OUTPUT:
---
fail_compilation/fail20618.d(13): Error: in slice `a[1LU...12LU]`, upper bound is greater than array length `10LU`
fail_compilation/fail20618.d(14): Error: in slice `a[18446744073709551615LU...3LU]`, lower bound is greater than upper bound
fail_compilation/fail20618.d(15): Error: in slice `a[0LU...11LU]`, upper bound is greater than array length `10LU`
---
*/

void main()
{
    int[10] a;
    auto b = a[1..12];
    auto c = a[-1..3];
    auto d = a[0..$ + 1];
}
