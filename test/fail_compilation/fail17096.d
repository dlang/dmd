class S
{
    void foo(){}
}

static assert(__traits(compiles, __traits(isArithmetic, S, "foo")));
static assert(__traits(compiles,__traits(isFloating, S, "foo")));
static assert(__traits(compiles,__traits(isIntegral, S, "foo")));
static assert(__traits(compiles,__traits(isScalar, S, "foo")));
static assert(__traits(compiles,__traits(isUnsigned, S, "foo")));
static assert(__traits(compiles,__traits(isAssociativeArray, S, "foo")));
static assert(__traits(compiles,__traits(isStaticArray, S, "foo")));
static assert(__traits(compiles,__traits(isAbstractClass, S, "foo")));
static assert(__traits(compiles,__traits(isFinalClass, S, "foo")));
static assert(__traits(compiles,__traits(isAbstractFunction, S, "foo")));
static assert(__traits(compiles,__traits(isVirtualFunction, S, "foo")));
static assert(__traits(compiles,__traits(isVirtualMethod, S, "foo")));
static assert(__traits(compiles,__traits(isOverrideFunction, S, "foo")));
static assert(__traits(compiles,__traits(isFinalFunction, S, "foo")));
static assert(__traits(compiles,__traits(isRef, S, "foo")));
static assert(__traits(compiles,__traits(isOut, S, "foo")));
static assert(__traits(compiles,__traits(isLazy, S, "foo")));

void main()
{}