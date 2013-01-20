/*
TEST_OUTPUT:
---
fail_compilation/diag2452.d(14): Error: class diag2452.C interface function I.f(float p) isn't implemented
---
*/

interface I
{
    void f(int p);
    void f(float p);
}

class C : I
{
    void f(int p) { }
}
