/*
REQUIRED_ARGS: -preview=in
TEST_OUTPUT:
---
fail_compilation/diagin.d(15): Error: function `foo` is not callable using argument types `()`
fail_compilation/diagin.d(15):        too few arguments, expected 1, got 0
fail_compilation/diagin.d(20):        `diagin.foo(in int)` declared here
fail_compilation/diagin.d(17): Error: template `foo1` is not callable using argument types `!()(bool[])`
fail_compilation/diagin.d(21):        Candidate is: `foo1(T)(in T v, string)`
---
 */

void main ()
{
    foo();
    bool[] lvalue;
    foo1(lvalue);
}

void foo(in int) {}
void foo1(T)(in T v, string) {}

// Ensure that `in` has a unique mangling
static assert(foo.mangleof       == `_D6diagin3fooFIiZv`);
static assert(foo1!int.mangleof  == `_D6diagin__T4foo1TiZQiFNaNbNiNfIiAyaZv`);
static assert(foo1!char.mangleof == `_D6diagin__T4foo1TaZQiFNaNbNiNfIaAyaZv`);
