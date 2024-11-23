/*
TEST_OUTPUT:
---
fail_compilation/fail8032.d(21): Error: function `fail8032.B.f` cannot determine overridden function
    override void f() { }
                  ^
---
*/
mixin template T()
{
    void f() { }
}

class A {
    mixin T;
    mixin T;
}

class B : A
{
    override void f() { }
    // raises "cannot determine overridden function" error.
}

void main(){}
