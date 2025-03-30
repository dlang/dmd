/*
TEST_OUTPUT:
---
fail_compilation/diag9191.d(16): Error: function `void diag9191.C1.aaa()` does not override any function, did you mean to override `void diag9191.B1.aa()`?
fail_compilation/diag9191.d(22): Error: function `diag9191.C2.aaa` does not override any function
fail_compilation/diag9191.d(33): Error: function `void diag9191.C3.foo()` does not override any function, did you mean to override `void diag9191.B2._foo()`?
fail_compilation/diag9191.d(38): Error: function `void diag9191.C4.toStringa()` does not override any function, did you mean to override `string object.Object.toString()`?
---
*/

interface I1 { void a(); }
class B1 { void aa(); }

class C1 : B1, I1
{
    override void aaa();
    void a() {}
}

class C2 : I1
{
    override void aaa();
    void a() {}
}

class B2
{
    void _foo(){}
}

class C3 : B2
{
    override void foo(){}
}

class C4
{
    override void toStringa(){}
}

void main()
{
}
