/*
TEST_OUTPUT:
---
fail_compilation/fail91.d(14): Error: struct `fail91.S` unknown size
    S* s = new S();
           ^
---
*/

struct S;

void main()
{
    S* s = new S();
}
