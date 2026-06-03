/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/prefix_qual.d(17): Deprecation: function declaration `f` has `const` type qualifier in prefix position
fail_compilation/prefix_qual.d(17):        either use return type `const(int)` instead or move qualifier after parameter list
fail_compilation/prefix_qual.d(18): Deprecation: function declaration `bar` has `const` type qualifier in prefix position
fail_compilation/prefix_qual.d(18):        either use return type `const(Foo*)` instead or move qualifier after parameter list
fail_compilation/prefix_qual.d(20): Deprecation: function declaration `g` has `inout` type qualifier in prefix position
fail_compilation/prefix_qual.d(20):        add `auto` if necessary and move `inout` after parameter list
---
*/

module m 2024;

struct Foo {
    ref const int f();
    shared const Foo* bar();
    // inferred return type
    inout g() => 2;
}
