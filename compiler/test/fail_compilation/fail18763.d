/*
TEST_OUTPUT:
---
fail_compilation/fail18763.d(11): Error: undefined identifier `Foo1`
---
*/

// https://github.com/dlang/dmd/issues/18763
// The spellchecker should not suggest `Foo` as a fix for `Foo1` here,
// since `Foo` is the very alias being declared (a recursive suggestion).
alias Foo = Foo1;
