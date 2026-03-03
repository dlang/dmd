struct S4
{
    this(ref inout S4) @system {}
}

struct V4
{
    int opApply(int delegate(Object) @safe dg) @safe
    {
        return dg(null);
    }
}

S4 s;

auto ref h4()
{
    foreach (_; V4())
    {
        return s;
    }
    return s;
}
