// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

template T()
{
    imports.fwdref12201a.FILE* fp;
}

struct S
{
    mixin T;
    import imports.fwdref12201a;
}
