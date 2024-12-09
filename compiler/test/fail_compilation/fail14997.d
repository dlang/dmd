// https://issues.dlang.org/show_bug.cgi?id=14997

/*
TEST_OUTPUT:
---
fail_compilation/fail14997.d(25): Error: none of the overloads of `this` are callable using argument types `()`
    auto a = new Foo;
             ^
fail_compilation/fail14997.d(20):        Candidates are: `fail14997.Foo.this(int a)`
    this (int a) {}
    ^
fail_compilation/fail14997.d(21):                        `fail14997.Foo.this(string a)`
    this (string a) {}
    ^
---
*/

class Foo
{
    this (int a) {}
    this (string a) {}
}
void main()
{
    auto a = new Foo;
}
