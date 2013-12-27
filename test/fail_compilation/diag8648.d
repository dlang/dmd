/*
TEST_OUTPUT:
---
fail_compilation/diag8648.d(21): Error: undefined identifier X
fail_compilation/diag8648.d(32): Error: template diag8648.foo does not match any function template declaration. Candidates are:
fail_compilation/diag8648.d(21):        diag8648.foo(T, n)(X!(T, n))
fail_compilation/diag8648.d(32): Error: template diag8648.foo(T, n)(X!(T, n)) cannot deduce template function from argument types !()(Foo!(int, 1))
fail_compilation/diag8648.d(23): Error: undefined identifier a
fail_compilation/diag8648.d(34): Error: template diag8648.bar does not match any function template declaration. Candidates are:
fail_compilation/diag8648.d(23):        diag8648.bar(T)(Foo!(T, a))
fail_compilation/diag8648.d(34): Error: template diag8648.bar(T)(Foo!(T, a)) cannot deduce template function from argument types !()(Foo!(int, 1))
fail_compilation/diag8648.d(23): Error: undefined identifier a
fail_compilation/diag8648.d(35): Error: template diag8648.bar does not match any function template declaration. Candidates are:
fail_compilation/diag8648.d(23):        diag8648.bar(T)(Foo!(T, a))
fail_compilation/diag8648.d(35): Error: template diag8648.bar(T)(Foo!(T, a)) cannot deduce template function from argument types !()(Foo!(int, f))
---
*/

struct Foo(T, alias a) {}

void foo(T, n)(X!(T, n) ) {}    // undefined identifier 'X'

void bar(T)(Foo!(T, a) ) {}     // undefined identifier 'a'

void main()
{
    template f() {}

    Foo!(int, 1) x;
    Foo!(int, f) y;

    foo(x);

    bar(x); // expression '1' vs undefined Type 'a'
    bar(y); // symbol 'f' vs undefined Type 'a'
}
