module imports.inline4a;

mixin template LengthField(alias sym)
{
    pragma(inline, true)
    size_t length() const
    {
        return sym.length;
    }
}

struct Data
{
    string data;
    mixin LengthField!data;

    pragma(inline, true)
    int opApply(scope int delegate(const Data) dg) {
        return dg(this);
    }
}

pragma(inline, true)
int value()
{
    return 10;
}
