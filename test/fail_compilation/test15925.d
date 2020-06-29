/*
PERMUTE_ARGS:
EXTRA_FILES: imports/imp15925.d
TEST_OUTPUT:
---
fail_compilation/test15925.d(19): Error: undefined identifier `X`
fail_compilation/test15925.d(19):        while evaluating: `static assert(X == 1)`
---
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
