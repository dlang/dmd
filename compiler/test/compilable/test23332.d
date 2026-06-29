// https://github.com/dlang/dmd/issues/23332
// Segfault generating a struct's static initializer symbol when it has a float member.
struct S { int a; double b; float c; }
__gshared S s = { 1, 2, 3 };
double f(double x) { return x * 2; }
