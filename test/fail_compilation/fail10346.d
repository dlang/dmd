/*
TEST_OUTPUT:
---
fail_compilation/fail10346.d(13): Error: undefined identifier T
fail_compilation/fail10346.d(16): Error: template fail10346.bar does not match any function template declaration. Candidates are:
fail_compilation/fail10346.d(13):        fail10346.bar(T x, T)(Foo!T)
fail_compilation/fail10346.d(16): Error: template fail10346.bar(T x, T)(Foo!T) cannot deduce template function from argument types !(10)(Foo!int)
fail_compilation/fail10346.d(16): Error: template instance bar!10 errors instantiating template
---
*/

struct Foo(T) {}
void bar(T x, T)(Foo!T) {}
void main() {
    Foo!int spam;
    bar!10(spam);
}
