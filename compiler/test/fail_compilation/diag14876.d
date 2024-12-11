/*
TEST_OUTPUT:
---
fail_compilation/diag14876.d(33): Deprecation: class `diag14876.Dep` is deprecated
alias X1 = Foo!(Dep[]);
           ^
fail_compilation/diag14876.d(34): Deprecation: class `diag14876.Dep` is deprecated
alias X2 = Foo!(Dep[1]);
           ^
fail_compilation/diag14876.d(35): Deprecation: class `diag14876.Dep` is deprecated
alias X3 = Foo!(Dep[int]);
           ^
fail_compilation/diag14876.d(36): Deprecation: class `diag14876.Dep` is deprecated
alias X4 = Foo!(int[Dep]);
           ^
fail_compilation/diag14876.d(37): Deprecation: class `diag14876.Dep` is deprecated
alias X5 = Foo!(Dep*);
           ^
fail_compilation/diag14876.d(38): Deprecation: class `diag14876.Dep` is deprecated
alias X6 = Foo!(Dep.Mem);
           ^
fail_compilation/diag14876.d(39): Deprecation: class `diag14876.Dep` is deprecated
alias X7 = Foo!(Dep[3..4]);
           ^
fail_compilation/diag14876.d(39): Error: can only slice type sequences, not `diag14876.Dep`
alias X7 = Foo!(Dep[3..4]);
           ^
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
