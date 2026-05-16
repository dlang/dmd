/*
TEST_OUTPUT:
---
fail_compilation/diag14876.d(24): Deprecation: class `diag14876.Dep` is deprecated
fail_compilation/diag14876.d(22):        `Dep` is declared here
fail_compilation/diag14876.d(25): Deprecation: class `diag14876.Dep` is deprecated
fail_compilation/diag14876.d(22):        `Dep` is declared here
fail_compilation/diag14876.d(26): Deprecation: class `diag14876.Dep` is deprecated
fail_compilation/diag14876.d(22):        `Dep` is declared here
fail_compilation/diag14876.d(27): Deprecation: class `diag14876.Dep` is deprecated
fail_compilation/diag14876.d(22):        `Dep` is declared here
fail_compilation/diag14876.d(28): Deprecation: class `diag14876.Dep` is deprecated
fail_compilation/diag14876.d(22):        `Dep` is declared here
fail_compilation/diag14876.d(29): Deprecation: class `diag14876.Dep` is deprecated
fail_compilation/diag14876.d(22):        `Dep` is declared here
fail_compilation/diag14876.d(30): Deprecation: class `diag14876.Dep` is deprecated
fail_compilation/diag14876.d(22):        `Dep` is declared here
fail_compilation/diag14876.d(30): Error: can only slice type sequences, not `diag14876.Dep`
---
*/

deprecated class Dep { class Mem {} }

alias X1 = Foo!(Dep[]);
alias X2 = Foo!(Dep[1]);
alias X3 = Foo!(Dep[int]);
alias X4 = Foo!(int[Dep]);
alias X5 = Foo!(Dep*);
alias X6 = Foo!(Dep.Mem);
alias X7 = Foo!(Dep[3..4]);

template Foo(T) {}
