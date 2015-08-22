import lib14555;

void main()
{
    auto dummyLinkA = new A();
    assert(Object.factory("lib14555.A") !is null);
    assert(Object.factory("lib14555.B") is null);
}
