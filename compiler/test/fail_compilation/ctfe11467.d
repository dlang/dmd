/*
TEST_OUTPUT:
---
fail_compilation/ctfe11467.d(45): Error: overlapping slice assignment `[0..4] = [1..5]`
    a[0 .. 4] = a[1 .. 5];
              ^
fail_compilation/ctfe11467.d(54):        called from here: `test11467a()`
static assert(test11467a());
                        ^
fail_compilation/ctfe11467.d(54):        while evaluating: `static assert(test11467a())`
static assert(test11467a());
^
fail_compilation/ctfe11467.d(51): Error: overlapping slice assignment `[1..5] = [0..4]`
    a[1 .. 5] = a[0 .. 4];
              ^
fail_compilation/ctfe11467.d(55):        called from here: `test11467b()`
static assert(test11467b());
                        ^
fail_compilation/ctfe11467.d(55):        while evaluating: `static assert(test11467b())`
static assert(test11467b());
^
fail_compilation/ctfe11467.d(60): Error: overlapping slice assignment `[0..4] = [1..5]`
    a[0 .. 4] = a[1 .. 5];
              ^
fail_compilation/ctfe11467.d(69):        called from here: `test11467c()`
static assert(test11467c());
                        ^
fail_compilation/ctfe11467.d(69):        while evaluating: `static assert(test11467c())`
static assert(test11467c());
^
fail_compilation/ctfe11467.d(66): Error: overlapping slice assignment `[1..5] = [0..4]`
    a[1 .. 5] = a[0 .. 4];
              ^
fail_compilation/ctfe11467.d(70):        called from here: `test11467d()`
static assert(test11467d());
                        ^
fail_compilation/ctfe11467.d(70):        while evaluating: `static assert(test11467d())`
static assert(test11467d());
^
---
*/
int test11467a()
{
    auto a = [0, 1, 2, 3, 4];
    a[0 .. 4] = a[1 .. 5];
    return 1;
}
int test11467b()
{
    auto a = [0, 1, 2, 3, 4];
    a[1 .. 5] = a[0 .. 4];
    return 1;
}
static assert(test11467a());
static assert(test11467b());

int test11467c()
{
    auto a = "abcde".dup;
    a[0 .. 4] = a[1 .. 5];
    return 1;
}
int test11467d()
{
    auto a = "abcde".dup;
    a[1 .. 5] = a[0 .. 4];
    return 1;
}
static assert(test11467c());
static assert(test11467d());
