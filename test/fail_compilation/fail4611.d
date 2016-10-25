/*
TEST_OUTPUT:
---
fail_compilation/fail4611.d(15): Error: Vec[1000000000] size 4 * 1000000000 exceeds size limit `int.max` (2GiB - 1) for static array
---
*/

struct Vec
{
    int x;
}

void main()
{
    Vec[1000_000_000] a;
}
