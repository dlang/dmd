/*
TEST_OUTPUT:
---
fail_compilation/fail20538.d(15): Error: found `=` when expecting `identifier`
fail_compilation/fail20538.d(15): Error: found `1` when expecting `identifier`
fail_compilation/fail20538.d(15): Error: found `,` when expecting `identifier`
fail_compilation/fail20538.d(16): Error: named enum cannot declare member with type
fail_compilation/fail20538.d(17): Error: found `,` when expecting `identifier`
---
*/

enum smth
{
    a,
    = 1,
    int x = 1,
    @a,
    @disable b
}
