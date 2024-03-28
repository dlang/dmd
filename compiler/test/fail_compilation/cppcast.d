/*
REQUIRED_ARGS: -wo -w
TEST_OUTPUT:
---
fail_compilation/cppcast.d(16): Warning: dynamic cast is not implemented for `extern(C++)` classes
fail_compilation/cppcast.d(16):        use `*cast(Derived*) &base` instead
Error: warnings are treated as errors
       Use -wi if you wish to treat warnings only as informational.
---
*/
extern(C++) class C { void f() { } }
extern(C++) class D : C { }

void main() @safe
{
    assert(cast(D)(new C) is null); // would fail as RTTI not checked
    auto c = cast(C)(new D); // OK
}
