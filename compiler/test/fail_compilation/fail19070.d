/*
TEST_OUTPUT:
---
fail_compilation/fail19070.d(17): Error: return value `S!int(x)` of type `S!int` does not match return type `immutable(S!int)`, and cannot be implicitly converted
fail_compilation/fail19070.d(20): Error: template instance `fail19070.S!int` error instantiating
---
*/

// https://github.com/dlang/dmd/issues/19070
// error message for converting return value with ctor/dtor is horrible

struct S(T)
{
    T *t;
    this(T *x) { t = x; }
    ~this() {}
    immutable(S) foo(T* x) { return S(x); }
}

S!int s;
