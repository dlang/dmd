/*
TEST_OUTPUT:
---
fail_compilation/fail20538.d(13): Error: found `=` when expecting `identifier`
fail_compilation/fail20538.d(13): Error: found `1` when expecting `identifier`
fail_compilation/fail20538.d(13): Error: found `,` when expecting `identifier`
---
*/

enum smth
{
    a,
    = 1,
    @disable b
}
