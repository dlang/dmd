// https://github.com/dlang/dmd/pull/23940
struct S { long x = 42; long y = 7; }
struct Zero { long x; }
interface I { void f(); }
interface J { void g(); }
class C : I, J { void f() {} void g() {} }
class D : C {}

T pass(T)(T value) { auto copy = value; return copy; }
struct Box(T) { T value; }

enum init = pass(__traits(initSymbol, S));
enum vtbl = pass(__traits(vtblSymbol, C));
enum ifaces = pass(__traits(interfaceSymbol, C));
enum longs = (() {
    auto value = cast(const(long)[]) init;
    return pass(value);
})();
enum vbytes = (() => cast(const(ubyte)[]) vtbl)();
enum ibytes = (() => cast(const(ubyte)[]) ifaces)();
enum structs = (() => cast(const(S)[]) init)();
enum boxed = (() => Box!(typeof(init))(init))();
enum array = (() => [init, init])();
enum zero = pass(__traits(initSymbol, Zero));
enum empty = pass(__traits(interfaceSymbol, D));
static assert(init.length == S.sizeof);
static assert(longs.length == 2);
static assert(structs.length == 1);
static assert(vbytes.length == vtbl.length * (void*).sizeof);
static assert(ibytes.length == ifaces.length * Interface.sizeof);
static assert(boxed.value.length == S.sizeof);
static assert(array[1].length == S.sizeof);
static assert(zero.length == Zero.sizeof);
static assert(empty.length == 0);

// Exercise static data emission as well as expression lowering of CTFE results.
__gshared const(long)[] storedLongs = longs;
__gshared const(ubyte)[] storedVtbl = vbytes;
__gshared const(ubyte)[] storedInterfaces = ibytes;
__gshared const(void)[] storedZero = zero;
__gshared const(Interface)[] storedEmpty = empty;

void main()
{
    assert(longs.length == 2 && longs[0] == 42 && longs[1] == 7);
    assert(storedLongs == longs);
    assert(structs.length == 1 && structs[0].x == 42 && structs[0].y == 7);
    assert(vbytes.length == vtbl.length * (void*).sizeof);
    assert(vbytes.ptr is cast(const(ubyte)*) __traits(vtblSymbol, C).ptr);
    assert(storedVtbl.ptr is vbytes.ptr && storedVtbl.length == vbytes.length);
    assert(ibytes.ptr is cast(const(ubyte)*) __traits(interfaceSymbol, C).ptr);
    assert(storedInterfaces.ptr is ibytes.ptr && storedInterfaces.length == ibytes.length);
    assert(ifaces[0].classinfo is I.classinfo);
    assert(ifaces[1].classinfo is J.classinfo);
    assert(vtbl.ptr is *cast(void***) cast(void*) new C);
    assert(zero.ptr is null && storedZero.ptr is null);
    assert(storedZero.length == Zero.sizeof);
    assert(empty.ptr is null && storedEmpty.ptr is null && storedEmpty.length == 0);
    assert((cast(const(long)[]) boxed.value)[0] == 42);
    assert((cast(const(long)[]) array[1])[1] == 7);
}
