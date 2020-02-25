/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/chkprintf.d(101): Deprecation: width argument `0L` for format specification `"%*.*d"` must be `int`, not `long`
fail_compilation/chkprintf.d(101): Deprecation: precision argument `1L` for format specification `"%*.*d"` must be `int`, not `long`
fail_compilation/chkprintf.d(101): Deprecation: argument `2L` for format specification `"%*.*d"` must be `int`, not `long`
fail_compilation/chkprintf.d(103): Deprecation: argument `4` for format specification `"%lld"` must be `long`, not `int`
fail_compilation/chkprintf.d(104): Deprecation: argument `5` for format specification `"%jd"` must be `core.stdc.stdint.intmax_t`, not `int`
fail_compilation/chkprintf.d(105): Deprecation: argument `6.00000` for format specification `"%zd"` must be `size_t`, not `double`
fail_compilation/chkprintf.d(106): Deprecation: argument `7.00000` for format specification `"%td"` must be `ptrdiff_t`, not `double`
fail_compilation/chkprintf.d(107): Deprecation: argument `8.00000L` for format specification `"%g"` must be `double`, not `real`
fail_compilation/chkprintf.d(108): Deprecation: argument `9.00000` for format specification `"%Lg"` must be `real`, not `double`
fail_compilation/chkprintf.d(109): Deprecation: argument `10` for format specification `"%p"` must be `void*`, not `int`
fail_compilation/chkprintf.d(110): Deprecation: argument `& u` for format specification `"%n"` must be `int*`, not `uint*`
fail_compilation/chkprintf.d(112): Deprecation: argument `& u` for format specification `"%lln"` must be `long*`, not `int*`
fail_compilation/chkprintf.d(113): Deprecation: argument `& u` for format specification `"%hn"` must be `short*`, not `int*`
fail_compilation/chkprintf.d(114): Deprecation: argument `& u` for format specification `"%hhn"` must be `byte*`, not `int*`
fail_compilation/chkprintf.d(115): Deprecation: argument `16L` for format specification `"%c"` must be `char`, not `long`
fail_compilation/chkprintf.d(116): Deprecation: argument `17L` for format specification `"%c"` must be `char`, not `long`
fail_compilation/chkprintf.d(117): Deprecation: argument `& u` for format specification `"%s"` must be `char*`, not `int*`
fail_compilation/chkprintf.d(118): Deprecation: argument `& u` for format specification `"%ls"` must be `wchar_t*`, not `int*`
---
*/


import core.stdc.stdio;

#line 100

void test1() {  printf("%*.*d\n", 0L, 1L, 2L); }
//void test3() {  printf("%ld\n", 3.0); }
void test4() {  printf("%lld\n", 4); }
void test5() {  printf("%jd\n", 5); }
void test6() {  printf("%zd\n", 6.0); }
void test7() {  printf("%td\n", 7.0); }
void test8() {  printf("%g\n", 8.0L); }
void test9() {  printf("%Lg\n", 9.0); }
void test10() {  printf("%p\n", 10); }
void test11() { uint u; printf("%n\n", &u); }
//void test12() { ushort u; printf("%ln\n", &u); }
void test13() { int u; printf("%lln\n", &u); }
void test14() { int u; printf("%hn\n", &u); }
void test15() { int u; printf("%hhn\n", &u); }
void test16() { printf("%c\n", 16L); }
void test17() { printf("%c\n", 17L); }
void test18() { int u; printf("%s\n", &u); }
void test19() { int u; printf("%ls\n", &u); }

