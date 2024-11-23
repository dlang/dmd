/*
TEST_OUTPUT:
---
fail_compilation/fail15626.d(14): Error: class `fail15626.D` C++ base class `C` needs at least one virtual function
    class D : C, I
    ^
---
*/

extern (C++)
{
    class C { }
    interface I { void f(); }
    class D : C, I
    {
        void f() { }
    }
}
