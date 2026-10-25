struct S { long x = 42; }
interface I {}
class C : I {}

struct Info
{
    typeof(__traits(initSymbol, S)) init;
    typeof(__traits(vtblSymbol, C)) vtbl;
    typeof(__traits(interfaceSymbol, C)) interfaces;
}

static immutable info = Info(__traits(initSymbol, S), __traits(vtblSymbol, C), __traits(interfaceSymbol, C));

void main()
{
    assert((cast(const(S)*) info.init.ptr).x == 42);

    C c = new C;
    assert(info.vtbl.ptr is *cast(void***) c);
    assert(__traits(vtblSymbol, C).ptr is *cast(void***) c);

    assert(info.interfaces is C.classinfo.interfaces);
    assert(__traits(interfaceSymbol, C) is C.classinfo.interfaces);
}
