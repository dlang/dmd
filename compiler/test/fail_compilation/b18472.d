// REQUIRED_ARGS: -betterC
/*
TEST_OUTPUT:
---
fail_compilation/b18472.d(14): Error: cannot use `new` in `@nogc` function `b18472.getFun.gcAlloc2`
---
*/
@nogc:

auto getFun() {
    if (__ctfe)
    {
        assert(__ctfe);
        static ubyte[] gcAlloc2() @nogc {return new ubyte[10];}
        return &gcAlloc2;
    }
    return null;
}

immutable fun = getFun();

extern(C) void main() {
    fun();
}
