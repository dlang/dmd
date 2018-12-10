/*
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/test15925.d(21): Error: undefined identifier `X`
fail_compilation/test15925.d(21):        while evaluating: `static assert(X == 1)`
---

https://issues.dlang.org/show_bug.cgi?id=15925

*/

mixin template Import()
{
    import imports.imp15925;
}

class Foo
{
    mixin Import!();
    static assert(X == 1);
}
