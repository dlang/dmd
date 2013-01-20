/*
TEST_OUTPUT:
---
fail_compilation/diag8807.d(12): Error: 'value' must be of integral or string type, it is a double
fail_compilation/diag8807.d(14): Error: case must be a string or an integral constant, not 1.000000
fail_compilation/diag8807.d(15): Error: case must be a string or an integral constant, not 2.100000
---
*/
void main()
{
    double value = 1;
    switch (value)
    {
        case 1.0: break;
        case 2.1: break;
        default:
    }
}
