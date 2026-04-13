// https://github.com/dlang/dmd/issues/20997 - valid alias arg with type specialization
// https://github.com/dlang/dmd/issues/20998 - mismatched alias arg with type specialization

/*
TEST_OUTPUT:
---
fail_compilation/template_alias_param.d(19): Error: template instance `Foo!1` does not match template declaration `Foo(alias s : S)`
fail_compilation/template_alias_param.d(20): Error: template instance `Foo!(T)` does not match template declaration `Foo(alias s : S)`
---
*/


struct S {}
struct T {}
template Foo(alias s : S) {}

alias F  = Foo!S; // valid: matching type specialization (issue 20997)
alias FC = Foo!(const(S));
alias G  = Foo!1; // invalid: expression should not match type specialization (issue 20998)
alias H  = Foo!T; // invalid: wrong type should not match (issue 20998)

template Bar(alias s : 3) {}
alias BG = Bar!3;
alias BH = Bar!(1 + 2);

template SpecConstS(alias s : const(S)) {}
alias CS3 = SpecConstS!S;
alias CS4 = SpecConstS!(const(S));
