/*
TEST_OUTPUT:
---
fail_compilation/diag10319.d(27): Error: `pure` function `D main` cannot call impure function `diag10319.foo`
fail_compilation/diag10319.d(27): Error: `@safe` function `D main` cannot call `@system` function `diag10319.foo`
fail_compilation/diag10319.d(16):        `diag10319.foo` is declared here
fail_compilation/diag10319.d(28): Error: `pure` function `D main` cannot call impure function `diag10319.bar!int.bar`
fail_compilation/diag10319.d(18):          could not infer `pure` for `diag10319.bar!int.bar` because:
fail_compilation/diag10319.d(20):          - accessing `g` is not `pure`
fail_compilation/diag10319.d(28): Error: `@safe` function `D main` cannot call `@system` function `diag10319.bar!int.bar`
fail_compilation/diag10319.d(18):        `diag10319.bar!int.bar` is declared here
fail_compilation/diag10319.d(27): Error: function `diag10319.foo` is not `nothrow`
fail_compilation/diag10319.d(28): Error: function `diag10319.bar!int.bar` is not `nothrow`
fail_compilation/diag10319.d(18):          could not infer `nothrow` for `diag10319.bar!int.bar` because:
fail_compilation/diag10319.d(22):          - throwing `object.Exception` here
fail_compilation/diag10319.d(25): Error: `nothrow` function `D main` may throw
---
*/
#line 16
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
