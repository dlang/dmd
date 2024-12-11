/*
TEST_OUTPUT:
---
fail_compilation/diag8648.d(36): Error: undefined identifier `X`
void foo(T, n)(X!(T, n) ) {}    // undefined identifier 'X'
               ^
fail_compilation/diag8648.d(47): Error: template `foo` is not callable using argument types `!()(Foo!(int, 1))`
    foo(x);
       ^
fail_compilation/diag8648.d(36):        Candidate is: `foo(T, n)(X!(T, n))`
void foo(T, n)(X!(T, n) ) {}    // undefined identifier 'X'
     ^
fail_compilation/diag8648.d(38): Error: undefined identifier `a`
void bar(T)(Foo!(T, a) ) {}     // undefined identifier 'a'
                    ^
fail_compilation/diag8648.d(49): Error: template `bar` is not callable using argument types `!()(Foo!(int, 1))`
    bar(x); // expression '1' vs undefined Type 'a'
       ^
fail_compilation/diag8648.d(38):        Candidate is: `bar(T)(Foo!(T, a))`
void bar(T)(Foo!(T, a) ) {}     // undefined identifier 'a'
     ^
fail_compilation/diag8648.d(38): Error: undefined identifier `a`
void bar(T)(Foo!(T, a) ) {}     // undefined identifier 'a'
                    ^
fail_compilation/diag8648.d(50): Error: template `bar` is not callable using argument types `!()(Foo!(int, f))`
    bar(y); // symbol 'f' vs undefined Type 'a'
       ^
fail_compilation/diag8648.d(38):        Candidate is: `bar(T)(Foo!(T, a))`
void bar(T)(Foo!(T, a) ) {}     // undefined identifier 'a'
     ^
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
