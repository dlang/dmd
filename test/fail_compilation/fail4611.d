/*
TEST_OUTPUT:
---
fail_compilation/fail4611.d(15): Error: index 1000000000 overflow for static array
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
