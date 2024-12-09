/*
TEST_OUTPUT:
---
fail_compilation/diag_err1.d(39): Error: undefined identifier `x`
    pragma(msg, [1,2,x].length);
                     ^
fail_compilation/diag_err1.d(39):        while evaluating `pragma(msg, [1, 2, x].length)`
    pragma(msg, [1,2,x].length);
    ^
fail_compilation/diag_err1.d(40): Error: undefined identifier `x`
    pragma(msg, (x + y).sizeof);
                 ^
fail_compilation/diag_err1.d(40): Error: undefined identifier `y`
    pragma(msg, (x + y).sizeof);
                     ^
fail_compilation/diag_err1.d(40):        while evaluating `pragma(msg, (x + y).sizeof)`
    pragma(msg, (x + y).sizeof);
    ^
fail_compilation/diag_err1.d(41): Error: undefined identifier `x`
    pragma(msg, (n += x).sizeof);
                      ^
fail_compilation/diag_err1.d(41):        while evaluating `pragma(msg, (n += x).sizeof)`
    pragma(msg, (n += x).sizeof);
    ^
fail_compilation/diag_err1.d(42): Error: incompatible types for `(s) ~ (n)`: `string` and `int`
    pragma(msg, (s ~ n).sizeof);
                 ^
fail_compilation/diag_err1.d(42):        while evaluating `pragma(msg, (s ~ n).sizeof)`
    pragma(msg, (s ~ n).sizeof);
    ^
---
*/

void main()
{
    int n;
    string s;

    pragma(msg, [1,2,x].length);
    pragma(msg, (x + y).sizeof);
    pragma(msg, (n += x).sizeof);
    pragma(msg, (s ~ n).sizeof);
}
