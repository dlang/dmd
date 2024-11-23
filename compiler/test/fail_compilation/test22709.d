/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test22709.d(19): Error: address of variable `local` assigned to `arr` with longer lifetime
    arr = local[];
        ^
fail_compilation/test22709.d(24): Error: address of variable `local` assigned to `arr` with longer lifetime
    arr = local[];
        ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=22709
@safe:

void escape(ref ubyte[] arr, ref ubyte[64] local)
{
    arr = local[];
}

void escape1(ref ubyte[64] local, ref ubyte[] arr)
{
    arr = local[];
}

ubyte[] getArr()
{
    ubyte[64] blob;
    ubyte[] arr;
    escape(arr, blob[]);
    return arr;
}
