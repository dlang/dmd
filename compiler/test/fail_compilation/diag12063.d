/*
TEST_OUTPUT:
---
fail_compilation/diag12063.d(18): Error: cannot generate value for `b`
fail_compilation/diag12063.d(15): Error: no property `max` for type `Foo`, perhaps `import std.algorithm;` is needed?
fail_compilation/diag12063.d(18): Error: incompatible types for `(Foo()) + (1)`: `Bar` and `int`
fail_compilation/diag12063.d(27): Error: cannot generate value for `b`
fail_compilation/diag12063.d(27): Error: incompatible types for `(S()) == (1)`: `S` and `int`
fail_compilation/diag12063.d(27): Error: incompatible types for `(S()) + (1)`: `S` and `int`
---
*/

struct Foo {}

enum Bar : Foo
{
    a = Foo(),
    b
}

struct S {
    S opBinary(string s: "+")() => this;
    enum max = 1; // wrong type
}

enum {
    a = S(),
    b
}

struct Q {
    //~ Q opBinary(string s: "+")(int) => this;
    enum max = Q();
}

enum {
    c = Q(),
    d
}

struct R {
    R opBinary(string s: "+")(int) => this;
    enum max = 10;
}

enum ER
{
    e = R(),
    f
}
