/*
TEST_OUTPUT:
---
fail_compilation/fail91.d(13): Error: struct fail91.S unknown size
fail_compilation/fail91.d(13): Error: struct fail91.S no size yet for forward reference
---
*/

struct S;

void main()
{
    S* s = new S();
}
