// https://github.com/dlang/dmd/issues/22556
// cast() must strip all qualifiers from the entire type, not just the top-level mod.
// typeSemantic calls transitive() on TypeNext types (arrays, AAs), which
// propagates the qualifier into the element/value type. The qualifier-stripping
// functions must recurse into next to undo that propagation.

void testAA()
{
    shared(int[int]) a;
    static assert(is(typeof(cast() a) == int[int]));

    shared const(int[int]) b;
    static assert(is(typeof(cast() b) == int[int]));

    const(int[int]) c;
    static assert(is(typeof(cast() c) == int[int]));
}

void testDynamicArray()
{
    shared(int[]) a;
    static assert(is(typeof(cast() a) == int[]));

    const(int[]) b;
    static assert(is(typeof(cast() b) == int[]));
}
