/*
TEST_OUTPUT:
---
fail_compilation/diag10319.d(31): Error: `pure` function `D main` cannot call impure function `diag10319.foo`
fail_compilation/diag10319.d(31): Error: `@safe` function `D main` cannot call `@system` function `diag10319.foo`
fail_compilation/diag10319.d(20):        `diag10319.foo` is declared here
fail_compilation/diag10319.d(32): Error: `pure` function `D main` cannot call impure function `diag10319.bar!int.bar`
fail_compilation/diag10319.d(24):        which wasn't inferred `pure` because of:
fail_compilation/diag10319.d(24):        `pure` function `diag10319.bar!int.bar` cannot access mutable static data `g`
fail_compilation/diag10319.d(32): Error: `@safe` function `D main` cannot call `@system` function `diag10319.bar!int.bar`
fail_compilation/diag10319.d(25):        which wasn't inferred `@safe` because of:
fail_compilation/diag10319.d(25):        cannot take address of local `x` in `@safe` function `bar`
fail_compilation/diag10319.d(22):        `diag10319.bar!int.bar` is declared here
fail_compilation/diag10319.d(31): Error: function `diag10319.foo` is not `nothrow`
fail_compilation/diag10319.d(32): Error: function `diag10319.bar!int.bar` is not `nothrow`
fail_compilation/diag10319.d(29): Error: function `D main` may throw but is marked as `nothrow`
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
