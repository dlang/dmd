/*
TEST_OUTPUT:
---
fail_compilation/diag9358.d(21): Error: `x` must be of integral or string type, it is a `double`
    switch (x)
    ^
fail_compilation/diag9358.d(23): Error: `case` expression must be a compile-time `string` or an integral constant, not `1.1`
        case 1.1: break;
        ^
fail_compilation/diag9358.d(24): Error: `case` expression must be a compile-time `string` or an integral constant, not `2.1`
        case 2.1: break;
        ^
fail_compilation/diag9358.d(34): Error: `case` expression must be a compile-time `string` or an integral constant, not `z`
        case z: break;
        ^
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
