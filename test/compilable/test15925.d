/* REQUIRED_ARGS: -transition=import -transition=checkimports -Icompilable/imports
PERMUTE_ARGS:
TEST_OUTPUT:
---
compilable/test15925.d(12): Deprecation: module `imp15925` from file compilable/imports/imp15925.d should be imported with 'import imp15925;'
compilable/test15925.d(18): Deprecation: local import search method found variable `imp15925.X` instead of nothing
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
