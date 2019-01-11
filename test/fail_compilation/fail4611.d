/*
TEST_OUTPUT:
---
fail_compilation/fail4611.d(15): Error: `Vec[$n$]` size 4 * $n$ exceeds 0x$h$ size limit for static array
---
*/

struct Vec
{
    int x;
}

void main()
{
    Vec[ptrdiff_t.max] a;
}
