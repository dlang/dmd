/*
TEST_OUTPUT:
---
fail_compilation/fail172.d(17): Error: can only initialize const member x inside constructor
fail_compilation/fail172.d(20): Error: can only initialize const member x inside constructor
---
*/

class C
{
    int x;
}

void main()
{
    const(C) c1 = new C();
    c1.x = 3;

    const C c2 = new C();
    c2.x = 3;
}
