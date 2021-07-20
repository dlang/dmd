/*
TEST_OUTPUT:
---
fail_compilation/fail20655.d(25): Error: `@safe` function `fail20655.g` cannot call `@system` function `fail20655.f1`
fail_compilation/fail20655.d(20):        `fail20655.f1` is declared here
fail_compilation/fail20655.d(26): Error: `@safe` function `fail20655.g` cannot call `@system` function `fail20655.f2!().f2`
fail_compilation/fail20655.d(21):        `fail20655.f2!().f2` is declared here
fail_compilation/fail20655.d(27): Error: `@safe` function `fail20655.g` cannot call `@system` function `fail20655.g.f3`
fail_compilation/fail20655.d(24):        `fail20655.g.f3` is declared here
---
*/

union U
{
    string s;
    int x;
}
U u;

auto f1() { auto s = u.s; } /* Should be inferred as @system. */
void f2()() { auto s = u.s; } /* ditto */
void g() @safe
{
    void f3() { auto s = u.s; } /* ditto */
    f1(); /* Should be rejected with error "cannot call @system function". */
    f2(); /* ditto */
    f3(); /* ditto */
}
