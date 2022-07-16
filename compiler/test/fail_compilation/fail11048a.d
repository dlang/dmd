// https://issues.dlang.org/show_bug.cgi?id=11048
/* TEST_OUTPUT:
---
fail_compilation/fail11048a.d(15): Error: `pure` function `fail11048a.foo` cannot access mutable static data `x`
fail_compilation/fail11048a.d(17): Error: `pure` function `fail11048a.foo` cannot access mutable static data `x`
fail_compilation/fail11048a.d(17): Error: function `fail11048a.baz(int a)` is not callable using argument types `(_error_)`
fail_compilation/fail11048a.d(17):        cannot pass argument `__error` of type `_error_` to parameter `int a`
---
*/
int x = 7;

void foo() pure
{
    // Does not detect use of mutable global and compiles when it shouldn't.
    bar();
    // Correctly detects the use of a mutable global and gives an error
    baz(x);
}

void bar(int a = x) pure {}

void baz(int a) pure {}
