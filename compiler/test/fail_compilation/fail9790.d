/*
TEST_OUTPUT:
---
fail_compilation/fail9790.d(21): Error: undefined identifier `_Unused_`
    enum bool _foo = _Unused_._unused_;
                     ^
fail_compilation/fail9790.d(28): Error: template instance `fail9790.foo!()` error instantiating
alias Foo = foo!();
            ^
fail_compilation/fail9790.d(26): Error: undefined identifier `_Unused_`
    enum bool bar = _Unused_._unused_;
                    ^
fail_compilation/fail9790.d(29): Error: template instance `fail9790.bar!()` error instantiating
alias Bar = bar!();
            ^
---
*/

template foo()
{
    enum bool _foo = _Unused_._unused_;
    enum bool foo = _foo;
}
template bar()
{
    enum bool bar = _Unused_._unused_;
}
alias Foo = foo!();
alias Bar = bar!();
