/*
TEST_OUTPUT:
---
fail_compilation/fail134.d(105): Error: template instance `foo!(f)` does not match template declaration `foo(T)`
fail_compilation/fail134.d(105):        instantiated from here: `foo!(f)`
fail_compilation/fail134.d(106):        instantiated from here: `bar!(f)`
fail_compilation/fail134.d(104):        Candidate match: foo(T)
fail_compilation/fail134.d(105):        `f` is not a type
---
*/

#line 100

// https://issues.dlang.org/show_bug.cgi?id=651
// Assertion failure: 'global.errors' on line 2622 in file 'template.c'
void f() {}
template foo(T) {}
template bar(T...) { alias foo!(T) buz; }
alias bar!(f) a;
