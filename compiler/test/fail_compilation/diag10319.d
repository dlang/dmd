/*
TEST_OUTPUT:
---
fail_compilation/diag10319.d(57): Error: `pure` function `D main` cannot call impure function `diag10319.foo`
    foo();      // L25
       ^
fail_compilation/diag10319.d(57): Error: `@safe` function `D main` cannot call `@system` function `diag10319.foo`
    foo();      // L25
       ^
fail_compilation/diag10319.d(46):        `diag10319.foo` is declared here
void foo() {}
     ^
fail_compilation/diag10319.d(58): Error: `pure` function `D main` cannot call impure function `diag10319.bar!int.bar`
    bar!int();  // L26
           ^
fail_compilation/diag10319.d(50):        which wasn't inferred `pure` because of:
    static int g; g = 10;       // impure
                  ^
fail_compilation/diag10319.d(50):        `pure` function `diag10319.bar!int.bar` cannot access mutable static data `g`
fail_compilation/diag10319.d(58): Error: `@safe` function `D main` cannot call `@system` function `diag10319.bar!int.bar`
    bar!int();  // L26
           ^
fail_compilation/diag10319.d(51):        which wasn't inferred `@safe` because of:
    int x; auto p = &x;         // system
                     ^
fail_compilation/diag10319.d(51):        cannot take address of local `x` in `@safe` function `bar`
fail_compilation/diag10319.d(48):        `diag10319.bar!int.bar` is declared here
void bar(T)()
     ^
fail_compilation/diag10319.d(57): Error: function `diag10319.foo` is not `nothrow`
    foo();      // L25
       ^
fail_compilation/diag10319.d(58): Error: function `diag10319.bar!int.bar` is not `nothrow`
    bar!int();  // L26
           ^
fail_compilation/diag10319.d(52):        which wasn't inferred `nothrow` because of:
    throw new Exception("");    // may throw
    ^
fail_compilation/diag10319.d(52):        `object.Exception` is thrown but not caught
fail_compilation/diag10319.d(55): Error: function `D main` may throw but is marked as `nothrow`
@safe pure nothrow void main()  // L23
                        ^
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
