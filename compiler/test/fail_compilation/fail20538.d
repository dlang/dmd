/*
TEST_OUTPUT:
---
fail_compilation/fail20538.d(19): Error: found `=` when expecting `identifier`
    = 1,
    ^
fail_compilation/fail20538.d(19): Error: found `1` when expecting `identifier`
    = 1,
      ^
fail_compilation/fail20538.d(20): Error: named enum cannot declare member with type
    int x = 1,
    ^
---
*/

enum smth
{
    a,
    = 1,
    int x = 1,
    @disable b
}
