// https://github.com/dlang/dmd/issues/23401

struct HasDtor { int x; ~this() {} }
class Base    { int marker; this() { marker = 42; } }
class Derived : Base { HasDtor field; this() {} }

void main()
{
    auto d = new Derived();
    assert(d.marker == 42);
}
