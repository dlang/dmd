// https://github.com/dlang/dmd/issues/21414

/* REQUIRED_ARGS: -o-
TEST_OUTPUT:
---
fail_compilation/fail21414.d(38): Error: moving variable `__rvalue(s)` with `__rvalue` is not allowed in a `@safe` function
fail_compilation/fail21414.d(38): Error: moving variable `__rvalue(s)` with `__rvalue` is not allowed in a `@safe` function
fail_compilation/fail21414.d(40): Error: calling `__rvalue`-annotated function `unsafeMove` is not allowed in a `@safe` function
fail_compilation/fail21414.d(40): Error: calling `__rvalue`-annotated function `unsafeMove` is not allowed in a `@safe` function
---
*/

@safe:

struct S
{
    int x;
    this(int x)
    {
        this.x = x;
    }
    ~this() { }
    this(S s) { }
}

void foo(S s, immutable(S) t)
{
    assert(t.x == 2);
    s.x = 3;
    assert(t.x == 2);
}

ref unsafeMove(T)(ref T arg) __rvalue => arg;

void main()
{
    auto s = S(2);
    foo(__rvalue(s), __rvalue(s));
    auto t = S(2);
    foo(unsafeMove(t), unsafeMove(t));
}
