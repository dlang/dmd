/*
TEST_OUTPUT:
---
fail_compilation/ice11856_0.d(25): Error: none of the overloads of template `ice11856_0.f` are callable using argument types `!()(int)`
enum x=f(2);
        ^
fail_compilation/ice11856_0.d(19):        Candidates are: `f(T)(T t)`
int f(T)(T t) if(!__traits(compiles,.f!T)) {
    ^
fail_compilation/ice11856_0.d(22):                        `f(T)(T t)`
  with `T = int`
  must satisfy the following constraint:
`       !__traits(compiles, .f!T)`
int f(T)(T t) if(!__traits(compiles,.f!T)) {
    ^
---
*/

int f(T)(T t) if(!__traits(compiles,.f!T)) {
    return 0;
}
int f(T)(T t) if(!__traits(compiles,.f!T)) {
    return 1;
}
enum x=f(2);
