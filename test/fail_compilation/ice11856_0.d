/*
TEST_OUTPUT:
---
fail_compilation/ice11856_0.d(16): Error: template `ice11856_0.f` cannot deduce function from argument types `!()(int)`, candidates are:
fail_compilation/ice11856_0.d(10):        `ice11856_0.f(T)(T t) if (!__traits(compiles, .f!T))`
fail_compilation/ice11856_0.d(13):        `ice11856_0.f(T)(T t) if (!__traits(compiles, .f!T))`
---
*/

int f(T)(T t) if(!__traits(compiles,.f!T)) {
    return 0;
}
int f(T)(T t) if(!__traits(compiles,.f!T)) {
    return 1;
}
enum x=f(2);
