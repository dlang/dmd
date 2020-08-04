/*
PERMUTE_ARGS: -preview=in
TEST_OUTPUT:
---
fail_compilation/diagin.d(18): Error: function `diagin.foo(in string)` is not callable using argument types `()`
fail_compilation/diagin.d(18):        missing argument for parameter #1: `in string`
fail_compilation/diagin.d(19): Error: function `diagin.foo1(in ref string)` is not callable using argument types `()`
fail_compilation/diagin.d(19):        missing argument for parameter #1: `in ref string`
fail_compilation/diagin.d(20): Error: template `diagin.foo2` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/diagin.d(27):        `foo2(T)(in T v, string)`
fail_compilation/diagin.d(22): Error: template `diagin.foo3` cannot deduce function from argument types `!()(bool[])`, candidates are:
fail_compilation/diagin.d(28):        `foo3(T)(in ref T v, string)`
---
 */

void main ()
{
    foo();
    foo1();
    foo2(42);
    bool[] lvalue;
    foo3(lvalue);
}

void foo(in string) {}
void foo1(in ref string) {}
void foo2(T)(in T v, string) {}
void foo3(T)(ref in T v, string) {}

// Ensure that `in` has a unique mangling
static assert(foo.mangleof       == `_D6diagin3fooFIxAyaZv`);
static assert(foo1.mangleof      == `_D6diagin4foo1FIKxAyaZv`);
static assert(foo2!int.mangleof  == `_D6diagin__T4foo2TiZQiFNaNbNiNfIxiAyaZv`);
static assert(foo3!char.mangleof == `_D6diagin__T4foo3TaZQiFNaNbNiNfIKxaAyaZv`);
