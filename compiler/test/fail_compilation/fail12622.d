/*
TEST_OUTPUT:
---
fail_compilation/fail12622.d(46): Error: `pure` function `fail12622.foo` cannot call impure function pointer `fp`
    (*fp)();
         ^
fail_compilation/fail12622.d(46): Error: `@nogc` function `fail12622.foo` cannot call non-@nogc function pointer `fp`
    (*fp)();
         ^
fail_compilation/fail12622.d(46): Error: `@safe` function `fail12622.foo` cannot call `@system` function pointer `fp`
    (*fp)();
         ^
fail_compilation/fail12622.d(48): Error: `pure` function `fail12622.foo` cannot call impure function pointer `fp`
    fp();
      ^
fail_compilation/fail12622.d(48): Error: `@nogc` function `fail12622.foo` cannot call non-@nogc function pointer `fp`
    fp();
      ^
fail_compilation/fail12622.d(48): Error: `@safe` function `fail12622.foo` cannot call `@system` function pointer `fp`
    fp();
      ^
fail_compilation/fail12622.d(50): Error: `pure` function `fail12622.foo` cannot call impure function `fail12622.bar`
    bar();
       ^
fail_compilation/fail12622.d(50): Error: `@safe` function `fail12622.foo` cannot call `@system` function `fail12622.bar`
    bar();
       ^
fail_compilation/fail12622.d(40):        `fail12622.bar` is declared here
void bar();
     ^
fail_compilation/fail12622.d(50): Error: `@nogc` function `fail12622.foo` cannot call non-@nogc function `fail12622.bar`
    bar();
       ^
---
*/
// Note that, today nothrow violation errors are accidentally hidden.



void bar();

pure nothrow @nogc @safe void foo()
{
    auto fp = &bar;

    (*fp)();

    fp();

    bar();
}
