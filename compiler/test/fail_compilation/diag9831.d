/*
TEST_OUTPUT:
---
fail_compilation/diag9831.d(13): Error: function `diag9831.main.__lambda_L13_C12(__T1)(x)` cannot access variable `c` in frame of function `D main`
fail_compilation/diag9831.d(11):        `c` declared here
---
*/

void main()
{
    immutable int c;
    int function(int x) func;
    func = x => c;
}
