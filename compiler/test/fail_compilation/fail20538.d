/*
TEST_OUTPUT:
---
fail_compilation/fail20538.d(14): Error: found `=` when expecting `identifier`
fail_compilation/fail20538.d(14): Error: found `1` when expecting `identifier`
fail_compilation/fail20538.d(14): Error: found `,` when expecting `identifier`
fail_compilation/fail20538.d(15): Error: found `,` when expecting `identifier`
---
*/

enum smth
{
    a,
    = 1,
    @a,
    @disable b
}
