/*
TEST_OUTPUT:
---
fail_compilation/fail240.d(11): Error: type `F` is not an expression
alias typeof(typeof(F).x) b;
                    ^
---
*/

class F { int x; }
alias typeof(typeof(F).x) b;
