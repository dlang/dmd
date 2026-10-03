// REQUIRED_ARGS: -c
// Unsupported CTFE operations must fail normally, including when gagged.
struct S { long x = 42; }
struct Three { ubyte[3] x = [1, 2, 3]; }
interface I {}
class C : I {}
struct Incomplete;
class Forward;

enum canEvaluate(alias fn) = __traits(compiles, { enum value = fn(); });
static assert(!canEvaluate!(() => (cast(const(ubyte)[]) __traits(initSymbol, S))[0]));
static assert(!canEvaluate!(() => __traits(vtblSymbol, C)[0]));
static assert(!canEvaluate!(() => __traits(getInterfaces, C)[0]));
static assert(!canEvaluate!(() => __traits(initSymbol, S)[0 .. 1]));
static assert(!canEvaluate!(() => __traits(initSymbol, S).ptr));
static assert(!canEvaluate!(() => cast(const(long)[]) __traits(initSymbol, Three)));
static assert(!canEvaluate!(() => __traits(vtblSymbol, C) == __traits(vtblSymbol, C)));
static assert(!canEvaluate!(() => __traits(vtblSymbol, C) ~ __traits(vtblSymbol, C)));
static assert(!canEvaluate!(() => [__traits(vtblSymbol, C)] == [__traits(vtblSymbol, C)]));
static assert(!canEvaluate!(() {
    const(void*)[] value = __traits(vtblSymbol, C);
    value ~= value;
    return value;
}));
static assert(!canEvaluate!(() {
    const(void*)[] value = __traits(vtblSymbol, C);
    value.length = value.length + 1;
    return value;
}));
static assert(!__traits(compiles, __traits(vtblSymbol, I)));
static assert(!__traits(compiles, __traits(vtblSymbol, int)));
static assert(!__traits(compiles, __traits(getInterfaces, S)));
static assert(!__traits(compiles, __traits(initSymbol, Incomplete)));
static assert(!__traits(compiles, __traits(vtblSymbol, Forward)));
