/*
TEST_OUTPUT:
---
fail_compilation/test9176.d(18): Error: forward reference to inferred return type of function call `get()`
    auto get() { return get(); }
                           ^
fail_compilation/test9176.d(14):        while evaluating: `static assert(!is(typeof(foo(S()))))`
static assert(!is(typeof(foo(S()))));
^
---
*/

void foo(int x) {}
static assert(!is(typeof(foo(S()))));

struct S
{
    auto get() { return get(); }
    alias get this;
}

void main(){}
