/*
TEST_OUTPUT:
---
fail_compilation/fail6178.d(17): Error: AA value setting through alias this (aa1[1].val.opAssign(1)) is not allowed
fail_compilation/fail6178.d(20): Error: AA value setting through alias this (aa2[1].val.num = 1) is not allowed
---
*/

struct X1 { void opAssign(int n) {} }
struct X2 { int num = 10; alias num this; }

struct S(X) { X val; alias val this; }

void main()
{
    S!X1[int] aa1;
    aa1[1] = 1;     // aa1[1].val.opAssign(1)

    S!X2[int] aa2;
    aa2[1] = 1;     // aa2[1].val.num = 1
}
