module imports.imp21539a;

mixin template TPriv()
{
    mixin TPrivInner;
}

mixin template TPrivInner()
{
    import imports.imp21539b;
    private alias X = int;
}

mixin template TPub()
{
    mixin TPubInner;
}

mixin template TPubInner()
{
    public import imports.imp21539b;
    alias X = int;
}

mixin template TPriv2()
{
    mixin TPrivInner;
    static assert(__traits(compiles, .File));
}

struct C
{
    mixin TPriv;
}

struct D
{
    mixin TPub;
}
