/*
TEST_OUTPUT:
---
fail_compilation/ctor_attr.d(40): Error: none of the overloads of `this` can construct a mutable object with argument types `(int)`
   auto s = S(1);
             ^
fail_compilation/ctor_attr.d(30):        Candidates are: `ctor_attr.S.this(int x) const`
    this(int x) const {}
    ^
fail_compilation/ctor_attr.d(32):                        `ctor_attr.S.this(string x)`
    this(string x) {}
    ^
fail_compilation/ctor_attr.d(31):                        `this()(int x) shared`
    this()(int x) shared {}
    ^
fail_compilation/ctor_attr.d(42): Error: none of the overloads of `foo` are callable using a mutable object with argument types `(int)`
   t.foo(1);
        ^
fail_compilation/ctor_attr.d(34):        Candidates are: `ctor_attr.S.foo(int x) immutable`
    void foo(int x) immutable  {}
         ^
fail_compilation/ctor_attr.d(35):                        `ctor_attr.S.foo(string x)`
    void foo(string x) {}
         ^
---
*/

struct S
{
    this(int x) const {}
    this()(int x) shared {}
    this(string x) {}

    void foo(int x) immutable  {}
    void foo(string x) {}
}

void f()
{
   auto s = S(1);
   S t;
   t.foo(1);
}
