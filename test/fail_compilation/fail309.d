/*
TEST_OUTPUT:
---
fail_compilation/fail309.d(10): Error: circular reference to 'fail309.S.x'
---
*/

struct S
{
    const x = S.x;
}
