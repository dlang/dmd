/*
TEST_OUTPUT:
---
fail_compilation/bug15613.d(33): Error: function `f` is not callable using argument types `(typeof(null))`
    f(null);
     ^
fail_compilation/bug15613.d(33):        cannot pass argument `null` of type `typeof(null)` to parameter `int...`
fail_compilation/bug15613.d(28):        `bug15613.f(int...)` declared here
void f(int...);
     ^
fail_compilation/bug15613.d(34): Error: function `g` is not callable using argument types `(int)`
    g(8);
     ^
fail_compilation/bug15613.d(34):        cannot pass argument `8` of type `int` to parameter `Object`
fail_compilation/bug15613.d(29):        `bug15613.g(Object, ...)` declared here
void g(Object, ...);
     ^
fail_compilation/bug15613.d(41): Error: function `h` is not callable using argument types `(int, void function(int[]...))`
    h(7, &h);
     ^
fail_compilation/bug15613.d(41):        cannot pass argument `& h` of type `void function(int[]...)` to parameter `int[]...`
fail_compilation/bug15613.d(37):        `bug15613.h(int[]...)` declared here
void h(int[]...);
     ^
---
*/

void f(int...);
void g(Object, ...);

void main()
{
    f(null);
    g(8);
}

void h(int[]...);

void test()
{
    h(7, &h);
}
