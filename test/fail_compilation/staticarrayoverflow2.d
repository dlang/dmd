/*
REQUIRED_ARGS: -m64
PERMUTE_ARGS: 
TEST_OUTPUT:
---
fail_compilation/staticarrayoverflow2.d(10): Error: long[18446744073709551615LU] static array size 8 * 18446744073709551615 overflowed to 18446744073709551608
---
*/

long[size_t.max] a;