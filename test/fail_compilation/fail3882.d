// REQUIRED_ARGS: -w
// PERMUTE_ARGS: -debug
/*
TEST_OUTPUT:
---
fail_compilation/fail3882.d(29): Warning: calling fail3882.strictlyPure!int.strictlyPure without side effects discards return value of type int, prepend a cast(void) if intentional
fail_compilation/fail3882.d(33): Warning: calling fp without side effects discards return value of type int, prepend a cast(void) if intentional
---
*/

@safe pure nothrow void strictVoidReturn(T)(T x)
{
}

@safe pure nothrow void nonstrictVoidReturn(T)(ref T x)
{
}

@safe pure nothrow T strictlyPure(T)(T x)
{
    return x*x;
}

void main()
{
    int x = 3;
    strictVoidReturn(x);
    nonstrictVoidReturn(x);
    strictlyPure(x);

    // 12649
    auto fp = &strictlyPure!int;
    fp(x);
}

/******************************************/
// 12619

extern (C) @system nothrow pure void* memcpy(void* s1, in void* s2, size_t n);
// -> weakly pure

void test12619() pure
{
    ubyte[10] a, b;
    debug memcpy(a.ptr, b.ptr, 5);  // memcpy call should have side effect
}
