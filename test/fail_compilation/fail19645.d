/*
TEST_OUTPUT:
---
fail_compilation/fail19645.d(26): Error: cast from `immutable(int)*` to `int*` not allowed in safe code
fail_compilation/fail19645.d(29): Error: Cannot call `@system` function `fail19645.non_pure` from `@safe` context
fail_compilation/fail19645.d(32): Error: Cannot access mutable static data `b` from a `pure` context
fail_compilation/fail19645.d(39): Error: Cannot call non-@nogc function `fail19645.m` from `@nogc` context
---
*/
int non_pure()
{
    return 2;
}

@safe:

immutable x = 42;

void main()
{
    *f() = 7;
    writeln(x); // 42
    writeln(*&x); // 7
}

int* f(int* y = cast(int*) &x) { return y; }


int f(int y = non_pure()) { return y; }

shared int b;
pure void g(int a=b){}
pure void k()
{
    g();
}

int m() { return 1; }
@nogc void g(int a = m()) {}
