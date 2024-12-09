/*
TEST_OUTPUT:
---
fail_compilation/fail307.d(13): Error: cannot implicitly convert expression `cast(int)(cast(double)cast(int)b + 6.1)` of type `int` to `short`
    short c5 = cast(int)(b + 6.1);
                         ^
---
*/

void main()
{
    ubyte b = 6;
    short c5 = cast(int)(b + 6.1);
}
