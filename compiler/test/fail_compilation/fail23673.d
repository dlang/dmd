/*
TEST_OUTPUT:
---
fail_compilation/fail23673.d(26): Error: constructor `fail23673.C.this(int x)` is not callable using argument types `()`
fail_compilation/fail23673.d(26):        too few arguments, expected 1, got 0
---
*/

// https://github.com/dlang/dmd/issues/23673

struct S
{
    int x;
    @disable this();
    this(int x) { this.x = x; }
}

class C
{
    S s;
    this(int x) { s = S(x); }
}

void test()
{
    auto c = new C();
}
