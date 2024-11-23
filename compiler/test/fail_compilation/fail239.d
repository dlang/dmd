/*
TEST_OUTPUT:
---
fail_compilation/fail239.d(10): Error: type `F` is not an expression
alias typeof(F).x b;
             ^
---
*/
class F { int x; }
alias typeof(F).x b;
