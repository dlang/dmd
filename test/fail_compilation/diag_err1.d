/*
TEST_OUTPUT:
---
fail_compilation/diag_err1.d(18): Error: undefined identifier x
fail_compilation/diag_err1.d(18):        while evaluating pragma(msg, [1, 2, x].length)
fail_compilation/diag_err1.d(19): Error: undefined identifier x
fail_compilation/diag_err1.d(19): Error: undefined identifier y
fail_compilation/diag_err1.d(19):        while evaluating pragma(msg, (x + y).sizeof)
fail_compilation/diag_err1.d(20): Error: undefined identifier x
fail_compilation/diag_err1.d(20):        while evaluating pragma(msg, (n += x).sizeof)
---
*/

void main()
{
    int n;

    pragma(msg, [1,2,x].length);
    pragma(msg, (x + y).sizeof);
    pragma(msg, (n += x).sizeof);
}
