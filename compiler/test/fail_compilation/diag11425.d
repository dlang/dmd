/*
TEST_OUTPUT:
---
fail_compilation/diag11425.d(18): Error: variable `x` is shadowing variable `diag11425.main.x`
        int x = 1;
        ^
fail_compilation/diag11425.d(15):        declared here
    int x;
        ^
---
*/

void main()
{
    int x;

    {
        int x = 1;
    }
}
