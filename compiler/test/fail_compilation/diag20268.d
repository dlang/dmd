// https://issues.dlang.org/show_bug.cgi?id=20268

/*
TEST_OUTPUT:
---
fail_compilation/diag20268.d(16): Error: template `__lambda_L15_C1` is not callable using argument types `!()(int)`
auto x = f(1);
          ^
fail_compilation/diag20268.d(15):        Candidate is: `__lambda_L15_C1(__T1, __T2)(x, y)`
alias f = (x,y) => true;
          ^
---
*/

alias f = (x,y) => true;
auto x = f(1);
