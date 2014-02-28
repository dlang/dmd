// REQUIRED_ARGS: -w
/*
TEST_OUTPUT:
---
fail_compilation/fail3882.d(26): Warning: Call to strictly pure function fail3882.strictlyPure!int.strictlyPure discards return value of type int, prepend a cast(void) if intentional
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

void main(string args[]) {
    int x = 3;
    strictVoidReturn(x);
    nonstrictVoidReturn(x);
    strictlyPure(x);
}
