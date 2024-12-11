/*
EXTRA_FILES: imports/imp15925.d
TEST_OUTPUT:
---
fail_compilation/test15925.d(22): Error: undefined identifier `X`
    static assert(X == 1);
                  ^
fail_compilation/test15925.d(22):        while evaluating: `static assert(X == 1)`
    static assert(X == 1);
    ^
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
