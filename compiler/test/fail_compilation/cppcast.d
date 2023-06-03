/*
TEST_OUTPUT:
---
fail_compilation/cppcast.d(12): Error: cast from `cppcast.C` to `cppcast.D` not allowed in safe code
---
*/
extern(C++) class C { void f() { } }
extern(C++) class D : C { }

void main() @safe
{
    assert(cast(D)(new C) is null); // would fail as RTTI not checked
    auto c = cast(C)(new D); // OK
}
