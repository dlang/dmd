/*
TEST_OUTPUT:
---
fail_compilation/test11176.d(12): Error: `(b).ptr` cannot be used in `@safe` code, use `&(b)[0]` instead
fail_compilation/test11176.d(16): Error: `(b).ptr` cannot be used in `@safe` code, use `&(b)[0]` instead
fail_compilation/test11176.d(21): Error: `[].ptr` cannot be used in `@safe` code
---
*/
// https://issues.dlang.org/show_bug.cgi?id=11176

@safe ubyte oops(ubyte[] b) {
    return *b.ptr;
}

@safe ubyte oops(ubyte[0] b) {
    return *b.ptr;
}

@safe ubyte cool(ubyte[1] b) {
    auto p = "".ptr;
    auto q = [].ptr; // error
    auto r = [ubyte(1)].ptr;
    return *b.ptr;
}

@system whatever(int[] a) => a.ptr;
