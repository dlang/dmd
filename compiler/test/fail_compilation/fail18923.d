/*
TEST_OUTPUT:
---
fail_compilation/fail18923.d(17): Error: function `foo` is not callable using argument types `((x) => "hello", (x) => x)`
fail_compilation/fail18923.d(17):        cannot pass argument `(x) => "hello"` of type `void` to parameter `double function(double) @safe __param_0`
fail_compilation/fail18923.d(13):        `fail18923.foo(double function(double) @safe __param_0, double function(double) @safe __param_1)` declared here
---
*/

// https://github.com/dlang/dmd/issues/18923
// Untyped lambda arguments that couldn't be matched should show their
// source text instead of a generic, unhelpful `void`.
void foo(double function(double) @safe,
         double function(double) @safe) {}
void test18923()
{
    foo(x => "hello", x => x);
}
