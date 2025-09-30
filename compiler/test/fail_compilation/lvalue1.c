/*
TEST_OUTPUT:
---
fail_compilation/lvalue1.c(19): Error: cannot modify expression `(c ? a : b).y` because it is not an lvalue
fail_compilation/lvalue1.c(20): Error: cannot modify expression `c ? a.z : b.z` because it is not an lvalue
fail_compilation/lvalue1.c(21): Error: conditional expression `c ? cast(short)a.x : cast(short)b.x` is not a modifiable lvalue
fail_compilation/lvalue1.c(25): Error: cannot take address of register variable `ax`
fail_compilation/lvalue1.c(25): Error: cannot take address of register variable `bx`
---
*/
typedef struct
{
    int x, y;
    int z : 16;
} S;

void lvalue1(S a, S b, int c)
{
    (c ? a : b).y = 1;
    (c ? a.z : b.z) = 2;
    (c ? (short)a.x : (short)b.x) = 3;

    register int ax;
    register int bx;
    *(c ? &ax : &bx) = 4;
}
