/*
TEST_OUTPUT:
---
fail_compilation/diag10319.d(112): Error: `pure` function `D main` cannot call impure function `diag10319.foo`
fail_compilation/diag10319.d(113): Error: `pure` function `D main` cannot call impure function `diag10319.bar!int.bar`
fail_compilation/diag10319.d(105):        which wasn't inferred `pure` because of:
fail_compilation/diag10319.d(105):        `pure` function `diag10319.bar!int.bar` cannot access mutable static data `g`
fail_compilation/diag10319.d(110): Error: function `D main` may throw but is marked as `nothrow`
---
*/

#line 100

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
