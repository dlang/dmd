/*
TEST_OUTPUT:
---
fail_compilation/fail298.d(13): Error: implicit conversion from `ulong` (64 bytes) to `int` (32 bytes) may truncate value
fail_compilation/fail298.d(13):        Use an explicit cast (e.g., `cast(int)expr`) to silence this.
---
*/

void main()
{
    ulong num1 = 100;
    int num2 = 10;
    int result = num1 / num2;
}
