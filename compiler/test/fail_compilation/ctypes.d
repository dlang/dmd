/*
TEST_OUTPUT:
---
fail_compilation/ctypes.d(15): Error: use `real` instead of `long double`
    long double r;
         ^
fail_compilation/ctypes.d(16): Error: use `long` for a 64 bit integer instead of `long long`
    long long ll;
         ^
---
*/

void test()
{
    long double r;
    long long ll;
}
