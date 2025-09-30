/* TEST_OUTPUT:
---
fail_compilation/bitfields2.c(103): Error: bitfield type `float` is not an integer type
fail_compilation/bitfields2.c(104): Error: bitfield width `3.0` is not an integer constant
fail_compilation/bitfields2.c(105): Error: bitfield `c` has zero width
fail_compilation/bitfields2.c(106): Error: width `60` of bitfield `d` does not fit in type `int`
---
 */

#line 100

struct S
{
    float a:3;
    int b:3.0;
    int c:0;
    int d:60;
};
