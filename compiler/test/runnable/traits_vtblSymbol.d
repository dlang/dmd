// The results of __traits(initSymbol), __traits(vtblSymbol) and __traits(interfaceSymbol)
// can be stored in static data at compile time, and refer to the real symbols.

struct S { long x = 42; }
struct Zero { long x; }
interface I { void f(); }
interface J { void g(); }
class C : I, J { void f() {} void g() {} }

struct Info
{
    SymbolSlice!(const void) init;
    SymbolSlice!(const(void*)) vtbl;
    SymbolSlice!(const Interface) interfaces;
    SymbolSlice!(const void) zero;
}

Info make()
{
    Info i;
    i.init = __traits(initSymbol, S);
    i.vtbl = __traits(vtblSymbol, C);
    i.interfaces = __traits(interfaceSymbol, C);
    i.zero = __traits(initSymbol, Zero);
    return i;
}

__gshared Info info = make();

void main()
{
    assert(info.init.length == S.sizeof);
    assert((cast(const(S)*) info.init.ptr).x == 42);

    C c = new C;
    assert(info.vtbl.length == 7);
    assert(info.vtbl.ptr is *cast(const(void*)**) c);

    assert(info.interfaces.length == 2);
    assert(info.interfaces[0].classinfo is I.classinfo);
    assert(info.interfaces[1].classinfo is J.classinfo);
    assert(info.interfaces is C.classinfo.interfaces);

    assert(info.zero.length == Zero.sizeof && info.zero.ptr is null);
}
