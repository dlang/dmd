// REQUIRED_ARGS: -c
// `__traits(initSymbol)`, `__traits(vtblSymbol)` and `__traits(interfaceSymbol)` are slices of
// symbols whose contents are only known at link time. CTFE can store them and read their
// length, but not their contents.

struct S
{
    int a = 1;
    long b = 2;
}

interface I { void f(); }
interface J { void g(); }

class C : I, J
{
    int x;
    void f() { }
    void g() { }
}

enum initS = (() => __traits(initSymbol, S))();
static assert(initS.length == S.sizeof);

enum initC = (() => __traits(initSymbol, C))();
static assert(initC.length == __traits(classInstanceSize, C));

enum vtblC = (() => __traits(vtblSymbol, C))();
static assert(vtblC.length == 7);   // ClassInfo slot, Object's 4 virtual methods, f, g

enum ifacesC = (() => __traits(interfaceSymbol, C))();
static assert(ifacesC.length == 2);
static assert(is(typeof(ifacesC) == const(Interface[])));

// they are ordinary slices at run time (not run here, compilable test)
void runtimeChecks()
{
    assert(__traits(initSymbol, S).length == S.sizeof);
    assert((cast(const(S)*) __traits(initSymbol, S).ptr).b == 2);
    assert(__traits(vtblSymbol, C).length == vtblC.length);
    assert(__traits(interfaceSymbol, C).length == 2);
    assert(__traits(interfaceSymbol, C)[0].classinfo is I.classinfo);
    assert(__traits(interfaceSymbol, C)[1].classinfo is J.classinfo);
    assert(__traits(interfaceSymbol, C).ptr is cast(const(Interface)*)(cast(void*) C.classinfo + __traits(classInstanceSize, TypeInfo_Class)));
}
