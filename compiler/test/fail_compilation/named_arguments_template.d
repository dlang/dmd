/*
TEST_OUTPUT:
---
fail_compilation/named_arguments_template.d(10): Error: named template arguments (`X: int`) are not supported yet
fail_compilation/named_arguments_template.d(10): Error: template instance `T!(X: int)` does not match template declaration `T(X)`
---
*/

template T(X) {}
alias I = T!(X: int);
