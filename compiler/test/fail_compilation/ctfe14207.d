/*
TEST_OUTPUT:
---
fail_compilation/ctfe14207.d(19): Error: cannot convert `&immutable(ulong)` to `ubyte[8]*` at compile time
    return *cast(ubyte[8]*) &res;
                            ^
fail_compilation/ctfe14207.d(24):        called from here: `nativeToBigEndian()`
    ubyte[8] bits = nativeToBigEndian();
                                     ^
fail_compilation/ctfe14207.d(28):        called from here: `digest()`
enum h = digest();
               ^
---
*/

ubyte[8] nativeToBigEndian()
{
    immutable ulong res = 1;
    return *cast(ubyte[8]*) &res;
}

auto digest()
{
    ubyte[8] bits = nativeToBigEndian();
    return bits;
}

enum h = digest();
