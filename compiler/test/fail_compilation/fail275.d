/*
TEST_OUTPUT:
---
fail_compilation/fail275.d(11): Error: circular reference to variable `fail275.C.x`
fail_compilation/fail275.d(11):        while resolving `fail275.C.x`
---
*/
// REQUIRED_ARGS: -d
struct C
{
    const x = C.x;
}
