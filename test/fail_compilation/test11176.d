
/*
REQUIRED_ARGS: -transition=safe
---
fail_compilation/test11176.d(12): Error: b.ptr cannot be used in @safe code, use &b[0] instead
fail_compilation/test11176.d(17): Error: b.ptr cannot be used in @safe code, use &b[0] instead
---
*/

// https://issues.dlang.org/show_bug.cgi?id=11176

@safe ubyte oops(ubyte[] b) {
    return *b.ptr;
}

@safe ubyte oops(ubyte[3] b) {
    return *b.ptr;
}

