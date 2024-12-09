/*
TEST_OUTPUT:
---
fail_compilation/fail18.d(16): Error: upper and lower bounds are needed to slice a pointer
    int[] a = (&x)[];
                  ^
---
*/

// 7/25
// Internal error: ..\ztc\cgcod.c 1464

void main ()
{
    int x = 3;
    int[] a = (&x)[];
}
