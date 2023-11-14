/*
TEST_OUTPUT:
---
fail_compilation/ctor_attr.d(24): Error: none of the overloads of `this` are callable using argument types `(int)`
fail_compilation/ctor_attr.d(15):        Candidates are: `ctor_attr.S.this(int x) const`
fail_compilation/ctor_attr.d(16):                        `ctor_attr.S.this(string x)`
fail_compilation/ctor_attr.d(26): Error: none of the overloads of `foo` are callable using a mutable object
fail_compilation/ctor_attr.d(18):        Candidates are: `ctor_attr.S.foo(int x) immutable`
fail_compilation/ctor_attr.d(19):                        `ctor_attr.S.foo(string x)`
---
*/

struct S
{
    this(int x) const {}
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
