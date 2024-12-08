/*
TEST_OUTPUT:
---
fail_compilation/fail309.d(12): Error: circular reference to variable `fail309.S.x`
    const x = S.x;
              ^
---
*/
// REQUIRED_ARGS: -d
struct S
{
    const x = S.x;
}
