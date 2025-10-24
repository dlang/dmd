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

    int opApply(scope int delegate(const Data) dg) {
        return dg(this);
    }
}
