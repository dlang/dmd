/* REQUIRED_ARGS: -m32
TEST_OUTPUT:
---
fail_compilation/fail4611.d(17): Error: `Vec[cast(size_t)2147483647]` size 4 * 2147483647 exceeds 0x7fffffff size limit for static array
    Vec[ptrdiff_t.max] a;
                       ^
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
