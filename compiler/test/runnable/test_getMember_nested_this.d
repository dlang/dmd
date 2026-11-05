// https://github.com/dlang/dmd/issues/23436
// __traits(getMember, this, "field") in a nested function must register
// a nested reference to the enclosing `this` so vthis appears in the
// closure frame.

struct Struct
{
    int field = 42;

    auto nestedThunk()
    {
        int inner()
        {
            return __traits(getMember, this, "field");
        }
        return &inner;
    }
}

void main()
{
    auto s = Struct();
    auto dg = s.nestedThunk();
    assert(dg() == 42);
}
