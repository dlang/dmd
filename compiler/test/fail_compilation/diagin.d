/*
REQUIRED_ARGS: -preview=in
TEST_OUTPUT:
---
fail_compilation/diagin.d(23): Error: function `foo` is not callable using argument types `()`
    foo();
       ^
fail_compilation/diagin.d(23):        too few arguments, expected 1, got 0
fail_compilation/diagin.d(28):        `diagin.foo(in int)` declared here
void foo(in int) {}
     ^
fail_compilation/diagin.d(25): Error: template `foo1` is not callable using argument types `!()(bool[])`
    foo1(lvalue);
        ^
fail_compilation/diagin.d(29):        Candidate is: `foo1(T)(in T v, string)`
void foo1(T)(in T v, string) {}
     ^
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
