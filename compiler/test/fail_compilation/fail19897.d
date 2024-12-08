/*
TEST_OUTPUT:
---
fail_compilation/fail19897.d(14): Error: cannot implicitly convert expression `a.x` of type `const(char[0])` to `const(char)`
const char c = a.x;
               ^
---
*/
struct S
{
    char[0] x;
}
const a = S('a');
const char c = a.x;
