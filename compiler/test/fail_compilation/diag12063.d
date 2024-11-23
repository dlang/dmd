/*
TEST_OUTPUT:
---
fail_compilation/diag12063.d(33): Error: cannot check `diag12063.Bar.b` value for overflow
    b // no max, can't +1
    ^
fail_compilation/diag12063.d(30): Error: no property `max` for type `Foo`, perhaps `import std.algorithm;` is needed?
enum Bar : Foo
^
fail_compilation/diag12063.d(33): Error: cannot generate value for `diag12063.Bar.b`
    b // no max, can't +1
    ^
fail_compilation/diag12063.d(33): Error: incompatible types for `(Foo()) + (1)`: `Bar` and `int`
    b // no max, can't +1
    ^
fail_compilation/diag12063.d(43): Error: cannot check `diag12063.b` value for overflow
    b // can't do S() == 1
    ^
fail_compilation/diag12063.d(43): Error: incompatible types for `(S()) == (1)`: `S` and `int`
    b // can't do S() == 1
    ^
fail_compilation/diag12063.d(52): Error: enum member `diag12063.d` initialization with `__anonymous.c+1` causes overflow for type `Q`
    d // overflow detected
    ^
---
*/

struct Foo {}

enum Bar : Foo
{
    a = Foo(),
    b // no max, can't +1
}

struct S {
    S opBinary(string s: "+")(int) => this;
    enum max = 1; // wrong type
}

enum {
    a = S(),
    b // can't do S() == 1
}

struct Q {
    enum max = Q();
}

enum {
    c = Q(),
    d // overflow detected
}

struct R {
    int i;
    R opBinary(string s: "+")(int) => this;
    enum max = R(1);
}

enum ER
{
    e = R(),
    f // OK
}
