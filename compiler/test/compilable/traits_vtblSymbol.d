// __traits(vtblSymbol) and __traits(interfaceSymbol)

interface I { void f(); }
interface J { void g(); }
class C : I, J { void f() {} void g() {} }
class D : C {}

static assert(is(typeof(__traits(vtblSymbol, C)) == SymbolSlice!(const(void*))));
static assert(is(typeof(__traits(interfaceSymbol, C)) == SymbolSlice!(const(Interface))));

static assert(__traits(vtblSymbol, C).length == 7);         // ClassInfo, 4 methods of Object, f, g
static assert(__traits(interfaceSymbol, C).length == 2);
static assert(__traits(interfaceSymbol, D).length == 0);    // inherited from C
static assert(__traits(interfaceSymbol, D).ptr is null);

/* The length is the same wherever it is asked for: the vtable is completed first,
 * whichever way its functions are declared.
 */
static assert(__traits(vtblSymbol, Later).length == 7);
class Later { void a() {} void b() {} }

class Members
{
    void a() {}
    enum first = __traits(vtblSymbol, Members).length;
    void b() {}
    static if (true) { void c() {} }
    static foreach (i; 0 .. 2) mixin("void f", i, "() {}");
    mixin("void d() {}");
    mixin M;
    version (none) { void x() {} }
    final void y() {}
    static void z() {}
    void t()() {}
}
mixin template M() { void m() {} }
static assert(Members.first == 12);
static assert(__traits(vtblSymbol, Members).length == 12);

class Override : C
{
    enum first = __traits(vtblSymbol, Override).length;
    override void f() {}
    void h() {}
}
static assert(Override.first == 8);
static assert(__traits(vtblSymbol, Override).length == 8);

class Interfaces : C, Later2
{
    enum first = __traits(interfaceSymbol, Interfaces).length;
}
interface Later2 {}
static assert(Interfaces.first == 1);
