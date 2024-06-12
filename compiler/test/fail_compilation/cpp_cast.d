// See also: fail20000.d
/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/cpp_cast.d(16): Deprecation: cast from `cpp_cast.C` to `cpp_cast.D` not allowed in safe code
fail_compilation/cpp_cast.d(16):        No dynamic type information for extern(C++) classes
---
*/
extern(C++) class C { void f() { } }
extern(C++) class D : C { }

void main() @safe
{
    C c;
    c = cast(D) new C; // reinterpret cast
    c = cast(C) new D; // OK
}
