/*
TEST_OUTPUT:
---
fail_compilation/diag10221a.d(11): Error: implicit conversion from `int` (32 bytes) to `ubyte` (8 bytes) may truncate value
fail_compilation/diag10221a.d(11):        Use an explicit cast (e.g., `cast(ubyte)expr`) to silence this.
---
*/

void main()
{
    foreach(ubyte i; 0..257) {}
}
