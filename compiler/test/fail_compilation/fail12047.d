// REQUIRED_ARGS: -d
/*
TEST_OUTPUT:
---
fail_compilation/fail12047.d(29): Error: undefined identifier `asdf`
@asdf void func() { }
 ^
fail_compilation/fail12047.d(30): Error: undefined identifier `asdf`
@asdf int var = 1;
 ^
fail_compilation/fail12047.d(31): Error: undefined identifier `asdf`
@asdf enum E : int { a }
 ^
fail_compilation/fail12047.d(32): Error: undefined identifier `asdf`
@asdf struct S {}
 ^
fail_compilation/fail12047.d(33): Error: undefined identifier `asdf`
@asdf class C {}
 ^
fail_compilation/fail12047.d(34): Error: undefined identifier `asdf`
@asdf interface I {}
 ^
fail_compilation/fail12047.d(35): Error: undefined identifier `asdf`
@asdf alias int myint;
 ^
---
*/

@asdf void func() { }
@asdf int var = 1;
@asdf enum E : int { a }
@asdf struct S {}
@asdf class C {}
@asdf interface I {}
@asdf alias int myint;
