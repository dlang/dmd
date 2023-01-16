/*
TEST_OUTPUT:
---
fail_compilation/diag9358.d(14): Error: `x` must be of integral or string type, it is a `double`
fail_compilation/diag9358.d(16): Error: `case` expression must be a compile-time `string` or an integral constant, not `1.1`
fail_compilation/diag9358.d(17): Error: `case` expression must be a compile-time `string` or an integral constant, not `2.1`
fail_compilation/diag9358.d(27): Deprecation: run-time `case` variables are deprecated, use if-else statements instead
fail_compilation/diag9358.d(27): Error: `case` expression must be a compile-time `string` or an integral constant, not `z`
---
*/
void main()
{
    double x;
    switch (x)
    {
        case 1.1: break;
        case 2.1: break;
        default:
    }
}

void f(immutable string y)
{
    auto z = y[0..2];
    switch (y)
    {
        case z: break;
        default:
    }
}
