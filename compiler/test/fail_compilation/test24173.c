/*
TEST_OUTPUT:
---
fail_compilation/test24173.c(101): Error: missing comma or semicolon after declaration of `a`, found `i` instead
fail_compilation/test24173.c(102): Error: missing comma or semicolon after declaration of `b`, found `i7` instead
fail_compilation/test24173.c(103): Error: missing comma or semicolon after declaration of `c`, found `i43` instead
fail_compilation/test24173.c(104): Error: invalid integer suffix
fail_compilation/test24173.c(104): Error: `=`, `;` or `,` expected to end declaration instead of `0`
---
*/

_Static_assert(-127i8 - 1 == 0xFFFFFF80, "1");
_Static_assert(-32767i16 - 1 == 0xFFFF8000, "2");
_Static_assert(-2147483647i32 - 1 == 0x80000000, "3");
_Static_assert(-9223372036854775807i64 - 1 == 0x8000000000000000, "4");

_Static_assert(127i8 == 0x7F, "5");
_Static_assert(32767i16 == 0x7FFF, "6");
_Static_assert(2147483647i32 == 0x7FFFFFFF, "7");
_Static_assert(9223372036854775807i64 == 0x7FFFFFFFFFFFFFFF, "8");

_Static_assert(127ui8 == 0x7F, "9");
_Static_assert(32767ui16 == 0x7FFF, "10");
_Static_assert(2147483647ui32 == 0x7FFFFFFF, "11");
_Static_assert(9223372036854775807ui64 == 0x7FFFFFFFFFFFFFFF, "12");

_Static_assert(0xffui8 == 0xFF, "13");
_Static_assert(0xffffui16 == 0xFFFF, "14");
_Static_assert(0xffffffffui32 == 0xFFFFFFFF, "15");
_Static_assert(0xFFFFFFFFFFFFFFFFui64 == 0xFFFFFFFFFFFFFFFF, "16");

#line 100

int a = 2i;
int b = 2i7;
int c = 2ui43;
int d = 2i160;
