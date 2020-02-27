/*
TEST_OUTPUT:
---
fail_compilation/diag10319.d(27): Error: `pure` function `D main` cannot call impure function `diag10319.foo`
fail_compilation/diag10319.d(27): Error: `@safe` function `D main` cannot call `@system` function `diag10319.foo`
fail_compilation/diag10319.d(16):        `diag10319.foo` is declared here
fail_compilation/diag10319.d(28): Error: `pure` function `D main` cannot call impure function `diag10319.bar!int`
fail_compilation/diag10319.d(28): Error: `@safe` function `D main` cannot call `@system` function `diag10319.bar!int`
fail_compilation/diag10319.d(18):        `diag10319.bar!int` is declared here
fail_compilation/diag10319.d(27): Error: function `diag10319.foo` is not `nothrow`
fail_compilation/diag10319.d(28): Error: function `diag10319.bar!int` is not `nothrow`
fail_compilation/diag10319.d(25): Error: `nothrow` function `D main` may throw
---
*/

void foo() {}

void bar(T)()
{
    static int g; g = 10;       // impure
    int x; auto p = &x;         // system
    throw new Exception("");    // may throw
}

@safe pure nothrow void main()  // L23
{
    foo();      // L25
    bar!int();  // L26
}
