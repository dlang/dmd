/*
TEST_OUTPUT:
---
fail_compilation/diag8648.d(12): Error: undefined identifier X
fail_compilation/diag8648.d(14): Error: undefined identifier a
fail_compilation/diag8648.d(14): Error: undefined identifier a
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
