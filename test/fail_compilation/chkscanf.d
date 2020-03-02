/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/chkscanf.d(101): Deprecation: argument `0L` for format specification `"%d"` must be `int*`, not `long`
fail_compilation/chkscanf.d(102): Deprecation: more format specifiers than 1 arguments
fail_compilation/chkscanf.d(103): Deprecation: argument `0L` for format specification `"%d"` must be `int*`, not `long`
fail_compilation/chkscanf.d(104): Deprecation: argument `0L` for format specification `"%3u"` must be `uint*`, not `long`
fail_compilation/chkscanf.d(105): Deprecation: argument `u` for format specification `"%200u"` must be `uint*`, not `uint`
fail_compilation/chkscanf.d(106): Deprecation: argument `3.00000` for format specification `"%hhd"` must be `byte*`, not `double`
fail_compilation/chkscanf.d(107): Deprecation: argument `4` for format specification `"%hd"` must be `short*`, not `int`
fail_compilation/chkscanf.d(109): Deprecation: argument `4` for format specification `"%lld"` must be `long*`, not `int`
fail_compilation/chkscanf.d(110): Deprecation: argument `5` for format specification `"%jd"` must be `core.stdc.stdint.intmax_t*`, not `int`
fail_compilation/chkscanf.d(111): Deprecation: argument `6.00000` for format specification `"%zd"` must be `size_t*`, not `double`
fail_compilation/chkscanf.d(112): Deprecation: argument `7.00000` for format specification `"%td"` must be `ptrdiff_t*`, not `double`
fail_compilation/chkscanf.d(113): Deprecation: format specifier `"%Ld"` is invalid
fail_compilation/chkscanf.d(114): Deprecation: argument `0` for format specification `"%u"` must be `uint*`, not `int`
fail_compilation/chkscanf.d(115): Deprecation: argument `0` for format specification `"%hhu"` must be `ubyte*`, not `int`
fail_compilation/chkscanf.d(116): Deprecation: argument `0` for format specification `"%hu"` must be `ushort*`, not `int`
fail_compilation/chkscanf.d(118): Deprecation: argument `0` for format specification `"%llu"` must be `ulong*`, not `int`
fail_compilation/chkscanf.d(119): Deprecation: argument `0` for format specification `"%ju"` must be `ulong*`, not `int`
fail_compilation/chkscanf.d(120): Deprecation: argument `0` for format specification `"%zu"` must be `size_t*`, not `int`
fail_compilation/chkscanf.d(121): Deprecation: argument `0` for format specification `"%tu"` must be `ptrdiff_t*`, not `int`
fail_compilation/chkscanf.d(122): Deprecation: argument `8.00000L` for format specification `"%g"` must be `float*`, not `real`
fail_compilation/chkscanf.d(123): Deprecation: argument `8.00000L` for format specification `"%lg"` must be `double*`, not `real`
fail_compilation/chkscanf.d(124): Deprecation: argument `9.00000` for format specification `"%Lg"` must be `real*`, not `double`
fail_compilation/chkscanf.d(125): Deprecation: argument `& u` for format specification `"%s"` must be `char*`, not `int*`
fail_compilation/chkscanf.d(126): Deprecation: argument `& u` for format specification `"%ls"` must be `wchar_t*`, not `int*`
fail_compilation/chkscanf.d(127): Deprecation: argument `v` for format specification `"%p"` must be `void**`, not `void*`
fail_compilation/chkscanf.d(128): Deprecation: argument `& u` for format specification `"%n"` must be `int*`, not `ushort*`
fail_compilation/chkscanf.d(129): Deprecation: argument `& u` for format specification `"%hhn"` must be `byte*`, not `int*`
fail_compilation/chkscanf.d(130): Deprecation: format specifier `"%[n"` is invalid
fail_compilation/chkscanf.d(131): Deprecation: format specifier `"%]"` is invalid
fail_compilation/chkscanf.d(132): Deprecation: argument `& u` for format specification `"%90s"` must be `char*`, not `int*`
fail_compilation/chkscanf.d(133): Deprecation: argument `0L` for format specification `"%d"` must be `int*`, not `long`
fail_compilation/chkscanf.d(134): Deprecation: argument `0L` for format specification `"%d"` must be `int*`, not `long`
---
*/


import core.stdc.stdio : fscanf, scanf, sscanf;

#line 100

void test1() {  scanf("%d\n", 0L); }
void test2() {  int i; scanf("%d %d\n", &i); }
void test3() {  scanf("%d%*c\n", 0L); }
void test4() {  scanf("%3u\n", 0L); }
void test5() {  uint u; scanf("%200u%*s\n", u); }
void test6() {  scanf("%hhd\n", 3.0); }
void test7() {  scanf("%hd\n", 4); }
//void test8() {  scanf("%ld\n", 3.0); }
void test9() {  scanf("%lld\n", 4); }
void test10() { scanf("%jd\n", 5); }
void test11() { scanf("%zd\n", 6.0); }
void test12() { scanf("%td\n", 7.0); }
void test13() { scanf("%Ld\n", 0); }
void test14() { scanf("%u\n", 0); }
void test15() { scanf("%hhu\n", 0); }
void test16() { scanf("%hu\n", 0); }
//void test17() { scanf("%lu\n", 0); }
void test18() { scanf("%llu\n", 0); }
void test19() { scanf("%ju\n", 0); }
void test20() { scanf("%zu\n", 0); }
void test21() { scanf("%tu\n", 0); }
void test22() { scanf("%g\n", 8.0L); }
void test23() { scanf("%lg\n", 8.0L); }
void test24() { scanf("%Lg\n", 9.0); }
void test25() { int u; scanf("%s\n", &u); }
void test26() { int u; scanf("%ls\n", &u); }
void test27() { void* v; scanf("%p\n", v); }
void test28() { ushort u; scanf("%n\n", &u); }
void test29() { int u; scanf("%hhn\n", &u); }
void test30() { int u; scanf("%[n", &u); }
void test31() { int u; scanf("%]\n", &u); }
void test32() { int u; scanf("%90s\n", &u); }
void test33() { sscanf("1234", "%d\n", 0L); }
void test34() { fscanf(null, "%d\n", 0L); }
