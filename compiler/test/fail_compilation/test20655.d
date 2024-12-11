/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/test20655.d(41): Deprecation: `@safe` function `g` calling `f1`
    f1(); // Should be rejected with error "cannot call @system function".
      ^
fail_compilation/test20655.d(36):        which wouldn't be `@safe` because of:
auto f1() { auto s = u.s; } // Should be inferred as @system.
                     ^
fail_compilation/test20655.d(36):        field `U.s` cannot access pointers in `@safe` code that overlap other fields
fail_compilation/test20655.d(42): Deprecation: `@safe` function `g` calling `f2`
    f2(); // ditto
      ^
fail_compilation/test20655.d(37):        which wouldn't be `@safe` because of:
void f2()() { auto s = u.s; } // ditto
                       ^
fail_compilation/test20655.d(37):        field `U.s` cannot access pointers in `@safe` code that overlap other fields
fail_compilation/test20655.d(43): Deprecation: `@safe` function `g` calling `f3`
    f3(); // ditto
      ^
fail_compilation/test20655.d(40):        which wouldn't be `@safe` because of:
    void f3() { auto s = u.s; } // ditto
                         ^
fail_compilation/test20655.d(40):        field `U.s` cannot access pointers in `@safe` code that overlap other fields
---
*/

union U
{
    string s;
    int x;
}
U u;

auto f1() { auto s = u.s; } // Should be inferred as @system.
void f2()() { auto s = u.s; } // ditto
void g() @safe
{
    void f3() { auto s = u.s; } // ditto
    f1(); // Should be rejected with error "cannot call @system function".
    f2(); // ditto
    f3(); // ditto
}
