/*
EXTRA_FILES: imports/imp15925.d
*/

// This test now compiles. See:
// https://issues.dlang.org/show_bug.cgi?id=21539

mixin template Import()
{
    import imports.imp15925;
}

class Foo
{
    mixin Import!();
    static assert(X == 1);
}
