/*
TEST_OUTPUT:
---
fail_compilation/diag9831.d(17): Error: function `diag9831.main.__lambda_L17_C12(__T1)(x)` cannot access variable `c` in frame of function `D main`
    func = x => c;
                ^
fail_compilation/diag9831.d(15):        `c` declared here
    immutable int c;
                  ^
---
*/

void main()
{
    immutable int c;
    int function(int x) func;
    func = x => c;
}
