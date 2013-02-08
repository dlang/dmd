/*
TEST_OUTPUT:
---
fail_compilation/diag9358.d(12): Error: 'x' must be of integral or string type, it is a double
fail_compilation/diag9358.d(14): Error: case must be a string or an integral constant, not 1.10000
fail_compilation/diag9358.d(15): Error: case must be a string or an integral constant, not 2.10000
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
