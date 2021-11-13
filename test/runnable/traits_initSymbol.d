module traits_initSymbol;

struct Zero { int x; }

struct NonZero { long x = 1; }

class C { short x = 123; }

void main()
{
    auto zeroInit = __traits(initSymbol, Zero);
    static assert(is(typeof(zeroInit) == const(void[])));
    assert(zeroInit.ptr is null && zeroInit.length == Zero.sizeof);

    auto nonZeroInit = __traits(initSymbol, NonZero);
    static assert(is(typeof(nonZeroInit) == const(void[])));
    assert(nonZeroInit.ptr !is null && nonZeroInit.length == NonZero.sizeof);
    assert(cast(const(long[])) nonZeroInit == [1L]);

    auto cInit = __traits(initSymbol, C);
    static assert(is(typeof(cInit) == const(void[])));
    assert(cInit.ptr !is null && cInit.length == __traits(classInstanceSize, C));
    scope c = new C;
    import core.stdc.string;
    assert(memcmp(cast(void*) c, cInit.ptr, cInit.length) == 0);

    static assert(!__traits(compiles, __traits(initSymbol, int)));
    static assert(!__traits(compiles, __traits(initSymbol, Zero[1])));
    static assert(!__traits(compiles, __traits(initSymbol, 123)));
}
