/*
TEST_OUTPUT:
---
fail_compilation/fail251.d(18): Error: undefined identifier `xs`
    foreach (x; xs) {}
                ^
fail_compilation/fail251.d(22):        called from here: `foo()`
static assert(foo());
                 ^
fail_compilation/fail251.d(22):        while evaluating: `static assert(foo())`
static assert(foo());
^
---
*/

bool foo()
{
    foreach (x; xs) {}
    return true;
}

static assert(foo());
