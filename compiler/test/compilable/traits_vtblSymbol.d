interface I { void f(); }
interface J { void g(); }
class C : I, J { void f() {} void g() {} }
class D : C {}

static assert(is(typeof(__traits(vtblSymbol, C)) == __SymbolSlice!(void*)));
static assert(is(typeof(__traits(interfaceSymbol, C)) == __SymbolSlice!Interface));

static assert(__traits(vtblSymbol, C).length == 7);
static assert(__traits(interfaceSymbol, C).length == 2);
static assert(__traits(interfaceSymbol, D).length == 0 && __traits(interfaceSymbol, D).ptr is null);
static assert(__traits(vtblSymbol, C).ptr is __traits(vtblSymbol, C).ptr);
static assert(__traits(vtblSymbol, C).ptr !is __traits(vtblSymbol, D).ptr);

static assert(__traits(vtblSymbol, Later).length == 7);
class Later { void a() {} void b() {} }

class Members
{
    void a() { static assert(__traits(vtblSymbol, Members).length == 7); }
    void b() {}
}

immutable(void*)[] vtbl() @safe => __traits(vtblSymbol, C);
