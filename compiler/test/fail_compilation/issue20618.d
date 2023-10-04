/* TEST_OUTPUT:
---
fail_compilation/issue20618.d(101): Error: in slice `a[1..12]`, upper bound is greater than array length `10`
fail_compilation/issue20618.d(101): Error: in slice `a[1..12]`, upper bound is greater than array length `10`
fail_compilation/issue20618.d(102): Error: in slice `a[4..3]`, lower bound is greater than upper bound
fail_compilation/issue20618.d(102): Error: in slice `a[4..3]`, lower bound is greater than upper bound
fail_compilation/issue20618.d(103): Error: in slice `a[0..11]`, upper bound is greater than array length `10`
fail_compilation/issue20618.d(103): Error: in slice `a[0..11]`, upper bound is greater than array length `10`
---
*/
// https://issues.dlang.org/show_bug.cgi?id=22198
void main()
{
    #line 100
    int[10] a;
    auto b = a[1..12];
    auto c = a[4..3];
    auto d = a[0..$ + 1];
}
