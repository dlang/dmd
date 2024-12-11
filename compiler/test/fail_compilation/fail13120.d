/*
TEST_OUTPUT:
---
fail_compilation/fail13120.d(32): Error: `pure` delegate `fail13120.g1.__foreachbody_L31_C5` cannot call impure function `fail13120.f1`
        f1();
          ^
fail_compilation/fail13120.d(32): Error: `@nogc` delegate `fail13120.g1.__foreachbody_L31_C5` cannot call non-@nogc function `fail13120.f1`
        f1();
          ^
fail_compilation/fail13120.d(44): Error: `pure` function `fail13120.h2` cannot call impure function `fail13120.g2!().g2`
    g2(null);
      ^
fail_compilation/fail13120.d(39):        which calls `fail13120.f2`
        f2();
          ^
fail_compilation/fail13120.d(44): Error: `@safe` function `fail13120.h2` cannot call `@system` function `fail13120.g2!().g2`
    g2(null);
      ^
fail_compilation/fail13120.d(36):        `fail13120.g2!().g2` is declared here
void g2()(char[] s)
     ^
fail_compilation/fail13120.d(44): Error: `@nogc` function `fail13120.h2` cannot call non-@nogc function `fail13120.g2!().g2`
    g2(null);
      ^
---
*/
void f1() {}

void g1(char[] s) pure @nogc
{
    foreach (dchar dc; s)
        f1();
}

void f2() {}
void g2()(char[] s)
{
    foreach (dchar dc; s)
        f2();
}

void h2() @safe pure @nogc
{
    g2(null);
}
