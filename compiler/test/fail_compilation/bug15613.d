/*
TEST_OUTPUT:
---
fail_compilation\bug15613.d(16): Error: function is not callable using argument types `(typeof(null))`
fail_compilation\bug15613.d(16):            `bug15613.f(int...)`
fail_compilation\bug15613.d(16):        cannot pass argument `null` of type `typeof(null)` to parameter `int...`
fail_compilation\bug15613.d(17): Error: function is not callable using argument types `(int)`
fail_compilation\bug15613.d(17):            `bug15613.g(Object, ...)`
fail_compilation\bug15613.d(17):        cannot pass argument `8` of type `int` to parameter `Object`
---
*/

void f(int...);
void g(Object, ...);

void main()
{
    f(null);
    g(8);
}

/*
TEST_OUTPUT:
---
fail_compilation\bug15613.d(32): Error: function is not callable using argument types `(int, void function(int[]...))`
fail_compilation\bug15613.d(32):            `bug15613.h(int[]...)`
fail_compilation\bug15613.d(32):        cannot pass argument `& h` of type `void function(int[]...)` to parameter `int[]...`
---
*/

void h(int[]...);

void test()
{
    h(7, &h);
}
