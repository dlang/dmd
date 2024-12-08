/*
TEST_OUTPUT:
---
fail_compilation/diag2452.d(16): Error: class `diag2452.C` interface function `void f(float p)` is not implemented
class C : I
^
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
