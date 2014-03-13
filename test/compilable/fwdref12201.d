// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

template T()
{
    alias imports.fwdref12201a.FILE* FP;
}

struct S
{
    mixin T;
    import imports.fwdref12201a;
}

union U
{
    mixin T;
    import imports.fwdref12201a;
}

class C
{
    mixin T;
    import imports.fwdref12201a;
}

interface I
{
    mixin T;
    import imports.fwdref12201a;
}


template TI()
{
    mixin T;
    import imports.fwdref12201a;
}
mixin template TM()
{
    mixin T;
    import imports.fwdref12201a;
}
struct S2
{
    alias ti = TI!();

    mixin TM;
}
