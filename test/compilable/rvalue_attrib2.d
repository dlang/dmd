// REQUIRED_ARGS: -preview=rvalueattribute

void fun(ref int a, @rvalue ref int b)
{
    static assert(__traits(isRef, a));
    static assert(__traits(isRvalueRef, b));
    static assert(!__traits(isRef, b));
}
