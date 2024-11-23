/*
TEST_OUTPUT:
---
fail_compilation/test11176.d(16): Error: `b.ptr` cannot be used in `@safe` code, use `&b[0]` instead
    return *b.ptr;
            ^
fail_compilation/test11176.d(20): Error: `b.ptr` cannot be used in `@safe` code, use `&b[0]` instead
    return *b.ptr;
            ^
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
    return *b.ptr;
}
