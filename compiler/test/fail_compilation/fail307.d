/*
TEST_OUTPUT:
---
fail_compilation/fail307.d(12): Error: implicit conversion from `int` (32 bytes) to `short` (16 bytes) may truncate value
fail_compilation/fail307.d(12):        Use an explicit cast (e.g., `cast(short)expr`) to silence this.
---
*/

void main()
{
    ubyte b = 6;
    short c5 = cast(int)(b + 6.1);
}
