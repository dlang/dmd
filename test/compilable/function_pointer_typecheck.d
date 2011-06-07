// PERMUTE_ARGS:

class Foo {}
class Bar : Foo {}

ref int refIntVoidFn();

void main() {
    // Check basic type differences and return type covariance.
    void function() voidVoid;
    void function(int) voidInt;
    Foo function() fooVoid;
    const(Foo) function() constFooVoid;
    Bar function() barVoid;

    static assert(__traits(compiles, voidVoid = voidVoid));
    static assert(!__traits(compiles, voidVoid = voidInt));
    static assert(!__traits(compiles, voidVoid = fooVoid));
    static assert(!__traits(compiles, voidVoid = constFooVoid));
    static assert(!__traits(compiles, voidVoid = barVoid));

    static assert(!__traits(compiles, voidInt = voidVoid));
    static assert(__traits(compiles, voidInt = voidInt));
    static assert(!__traits(compiles, voidInt = fooVoid));
    static assert(!__traits(compiles, voidInt = constFooVoid));
    static assert(!__traits(compiles, voidInt = barVoid));

    static assert(!__traits(compiles, fooVoid = voidVoid));
    static assert(!__traits(compiles, fooVoid = voidInt));
    static assert(__traits(compiles, fooVoid = fooVoid));
    static assert(!__traits(compiles, fooVoid = constFooVoid));
    static assert( __traits(compiles, fooVoid = barVoid));

    static assert(!__traits(compiles, constFooVoid = voidVoid));
    static assert(__traits(compiles, constFooVoid = fooVoid));
    static assert(!__traits(compiles, constFooVoid = voidInt));
    static assert(__traits(compiles, constFooVoid = constFooVoid));
    static assert(__traits(compiles, constFooVoid = barVoid));

    // Make sure calling convention mixing is not allowed.
    extern(C) void function() cFunc;
    static assert(!__traits(compiles, voidVoid = cfunc));
    static assert(!__traits(compiles, cFunc = voidVoid));

    // Make sure ref and value return are not compatible.
    typeof(&refIntVoidFn) refIntVoid;
    int function() intVoid;
    static assert(!__traits(compiles, intVoid = refIntVoid));
    static assert(!__traits(compiles, refIntVoid = intVoid));

    // Make sure variadic functions are not compatible with non-variadic ones.
    void function(...) voidVariadic;
    static assert(!__traits(compiles, voidVariadic = voidVoid));
    static assert(!__traits(compiles, voidVoid = voidVariadic));

    // Make sure level of trust restrictions can be relaxed but not tightened.
    void function() @system systemFunc;
    void function() @trusted trustedFunc;
    void function() @safe safeFunc;
    static assert(__traits(compiles, trustedFunc = safeFunc));
    static assert(__traits(compiles, systemFunc = safeFunc));
    static assert(__traits(compiles, systemFunc = trustedFunc));
    static assert(__traits(compiles, safeFunc = trustedFunc));
    static assert(!__traits(compiles, trustedFunc = systemFunc));
    static assert(!__traits(compiles, safeFunc = systemFunc));

    // Check that a nothrow function pointer is assignable to a non-nothrow
    // one, but not the other way round.
    void function() nothrow voidVoidNothrow;
    static assert(__traits(compiles, voidVoid = voidVoidNothrow));
    static assert(!__traits(compiles, voidVoidNothrow = voidVoid));

    // Same for purity.
    void function() pure voidVoidPure;
    static assert(__traits(compiles, voidVoid = voidVoidPure));
    static assert(!__traits(compiles, voidVoidPure = voidVoid));

    // Cannot convert parameter storage classes (except const to in and in to const)
    void function(const(int)) constFunc;
    void function(in int) inFunc;
    void function(out int) outFunc;
    void function(ref int) refFunc;
    void function(lazy int) lazyFunc;
    static assert(__traits(compiles, inFunc = constFunc));
    static assert(__traits(compiles, constFunc = inFunc));
    static assert(!__traits(compiles, inFunc = outFunc));
    static assert(!__traits(compiles, inFunc = refFunc));
    static assert(!__traits(compiles, inFunc = lazyFunc));
    static assert(!__traits(compiles, outFunc = inFunc));
    static assert(!__traits(compiles, outFunc = refFunc));
    static assert(!__traits(compiles, outFunc = lazyFunc));
    static assert(!__traits(compiles, refFunc = inFunc));
    static assert(!__traits(compiles, refFunc = outFunc));
    static assert(!__traits(compiles, refFunc = lazyFunc));
    static assert(!__traits(compiles, lazyFunc = inFunc));
    static assert(!__traits(compiles, lazyFunc = outFunc));
    static assert(!__traits(compiles, lazyFunc = refFunc));

    // Test all the conversions at once.
    void function(const(int)) @safe pure nothrow restrictedFunc;
    void function(in int) relaxedFunc = restrictedFunc;
}