/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/cppcast.d(13): Deprecation: dynamic cast not supported for `extern(C++)` class
---
*/
extern(C++) class C { void f() { } }
extern(C++) class D : C { }

void main() @safe
{
    assert(cast(D)(new C) is null); // would fail as RTTI not checked
}
