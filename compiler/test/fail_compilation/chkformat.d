/*
REQUIRED_ARGS: -de
DISABLED: win32 win64 linux32
TEST_OUTPUT:
---
fail_compilation/chkformat.d(224): Deprecation: width argument `0L` for format specification `"%*.*d"` must be `int`, not `long`
void test1() {  printf("%*.*d\n", 0L, 1L, 2L); }
                                  ^
fail_compilation/chkformat.d(224): Deprecation: precision argument `1L` for format specification `"%*.*d"` must be `int`, not `long`
void test1() {  printf("%*.*d\n", 0L, 1L, 2L); }
                                      ^
fail_compilation/chkformat.d(224): Deprecation: argument `2L` for format specification `"%*.*d"` must be `int`, not `long`
void test1() {  printf("%*.*d\n", 0L, 1L, 2L); }
                                          ^
fail_compilation/chkformat.d(227): Deprecation: argument `4` for format specification `"%lld"` must be `long`, not `int`
void test4() {  printf("%lld\n", 4); }
                                 ^
fail_compilation/chkformat.d(228): Deprecation: argument `5` for format specification `"%jd"` must be `core.stdc.stdint.intmax_t`, not `int`
void test5() {  printf("%jd\n", 5); }
                                ^
fail_compilation/chkformat.d(229): Deprecation: argument `6.0` for format specification `"%zd"` must be `size_t`, not `double`
void test6() {  printf("%zd\n", 6.0); }
                                ^
fail_compilation/chkformat.d(230): Deprecation: argument `7.0` for format specification `"%td"` must be `ptrdiff_t`, not `double`
void test7() {  printf("%td\n", 7.0); }
                                ^
fail_compilation/chkformat.d(231): Deprecation: argument `8.0L` for format specification `"%g"` must be `double`, not `real`
void test8() {  printf("%g\n", 8.0L); }
                               ^
fail_compilation/chkformat.d(232): Deprecation: argument `9.0` for format specification `"%Lg"` must be `real`, not `double`
void test9() {  printf("%Lg\n", 9.0); }
                                ^
fail_compilation/chkformat.d(233): Deprecation: argument `10` for format specification `"%p"` must be `void*`, not `int`
void test10() {  printf("%p\n", 10); }
                                ^
fail_compilation/chkformat.d(234): Deprecation: argument `& u` for format specification `"%n"` must be `int*`, not `uint*`
void test11() { uint u; printf("%n\n", &u); }
                                       ^
fail_compilation/chkformat.d(236): Deprecation: argument `& u` for format specification `"%lln"` must be `long*`, not `int*`
void test13() { int u; printf("%lln\n", &u); }
                                        ^
fail_compilation/chkformat.d(237): Deprecation: argument `& u` for format specification `"%hn"` must be `short*`, not `int*`
void test14() { int u; printf("%hn\n", &u); }
                                       ^
fail_compilation/chkformat.d(238): Deprecation: argument `& u` for format specification `"%hhn"` must be `byte*`, not `int*`
void test15() { int u; printf("%hhn\n", &u); }
                                        ^
fail_compilation/chkformat.d(239): Deprecation: argument `16L` for format specification `"%c"` must be `char`, not `long`
void test16() { printf("%c\n", 16L); }
                               ^
fail_compilation/chkformat.d(240): Deprecation: argument `17L` for format specification `"%c"` must be `char`, not `long`
void test17() { printf("%c\n", 17L); }
                               ^
fail_compilation/chkformat.d(241): Deprecation: argument `& u` for format specification `"%s"` must be `char*`, not `int*`
void test18() { int u; printf("%s\n", &u); }
                                      ^
fail_compilation/chkformat.d(242): Deprecation: argument `& u` for format specification `"%ls"` must be `wchar_t*`, not `int*`
void test19() { int u; printf("%ls\n", &u); }
                                       ^
fail_compilation/chkformat.d(246): Deprecation: argument `p` for format specification `"%n"` must be `int*`, not `const(int)*`
void test22() { int i; const(int)* p = &i; printf("%n", p); }
                                                        ^
fail_compilation/chkformat.d(250): Deprecation: argument `0L` for format specification `"%d"` must be `int*`, not `long`
void test31() {  scanf("%d\n", 0L); }
                               ^
fail_compilation/chkformat.d(251): Deprecation: more format specifiers than 1 arguments
void test32() {  int i; scanf("%d %d\n", &i); }
                              ^
fail_compilation/chkformat.d(252): Deprecation: argument `0L` for format specification `"%d"` must be `int*`, not `long`
void test33() {  scanf("%d%*c\n", 0L); }
                                  ^
fail_compilation/chkformat.d(253): Deprecation: argument `0L` for format specification `"%3u"` must be `uint*`, not `long`
void test34() {  scanf("%3u\n", 0L); }
                                ^
fail_compilation/chkformat.d(254): Deprecation: argument `u` for format specification `"%200u"` must be `uint*`, not `uint`
void test35() {  uint u; scanf("%200u%*s\n", u); }
                                             ^
fail_compilation/chkformat.d(255): Deprecation: argument `3.0` for format specification `"%hhd"` must be `byte*`, not `double`
void test36() {  scanf("%hhd\n", 3.0); }
                                 ^
fail_compilation/chkformat.d(256): Deprecation: argument `4` for format specification `"%hd"` must be `short*`, not `int`
void test37() {  scanf("%hd\n", 4); }
                                ^
fail_compilation/chkformat.d(258): Deprecation: argument `4` for format specification `"%lld"` must be `long*`, not `int`
void test39() {  scanf("%lld\n", 4); }
                                 ^
fail_compilation/chkformat.d(259): Deprecation: argument `5` for format specification `"%jd"` must be `core.stdc.stdint.intmax_t*`, not `int`
void test40() { scanf("%jd\n", 5); }
                               ^
fail_compilation/chkformat.d(260): Deprecation: argument `6.0` for format specification `"%zd"` must be `size_t*`, not `double`
void test41() { scanf("%zd\n", 6.0); }
                               ^
fail_compilation/chkformat.d(261): Deprecation: argument `7.0` for format specification `"%td"` must be `ptrdiff_t*`, not `double`
void test42() { scanf("%td\n", 7.0); }
                               ^
fail_compilation/chkformat.d(262): Deprecation: format specifier `"%Ld"` is invalid
void test43() { scanf("%Ld\n", 0); }
                      ^
fail_compilation/chkformat.d(263): Deprecation: argument `0` for format specification `"%u"` must be `uint*`, not `int`
void test44() { scanf("%u\n", 0); }
                              ^
fail_compilation/chkformat.d(264): Deprecation: argument `0` for format specification `"%hhu"` must be `ubyte*`, not `int`
void test45() { scanf("%hhu\n", 0); }
                                ^
fail_compilation/chkformat.d(265): Deprecation: argument `0` for format specification `"%hu"` must be `ushort*`, not `int`
void test46() { scanf("%hu\n", 0); }
                               ^
fail_compilation/chkformat.d(267): Deprecation: argument `0` for format specification `"%llu"` must be `ulong*`, not `int`
void test48() { scanf("%llu\n", 0); }
                                ^
fail_compilation/chkformat.d(268): Deprecation: argument `0` for format specification `"%ju"` must be `core.stdc.stdint.uintmax_t*`, not `int`
void test49() { scanf("%ju\n", 0); }
                               ^
fail_compilation/chkformat.d(269): Deprecation: argument `0` for format specification `"%zu"` must be `size_t*`, not `int`
void test50() { scanf("%zu\n", 0); }
                               ^
fail_compilation/chkformat.d(270): Deprecation: argument `0` for format specification `"%tu"` must be `ptrdiff_t*`, not `int`
void test51() { scanf("%tu\n", 0); }
                               ^
fail_compilation/chkformat.d(271): Deprecation: argument `8.0L` for format specification `"%g"` must be `float*`, not `real`
void test52() { scanf("%g\n", 8.0L); }
                              ^
fail_compilation/chkformat.d(272): Deprecation: argument `8.0L` for format specification `"%lg"` must be `double*`, not `real`
void test53() { scanf("%lg\n", 8.0L); }
                               ^
fail_compilation/chkformat.d(273): Deprecation: argument `9.0` for format specification `"%Lg"` must be `real*`, not `double`
void test54() { scanf("%Lg\n", 9.0); }
                               ^
fail_compilation/chkformat.d(274): Deprecation: argument `& u` for format specification `"%s"` must be `char*`, not `int*`
void test55() { int u; scanf("%s\n", &u); }
                                     ^
fail_compilation/chkformat.d(275): Deprecation: argument `& u` for format specification `"%ls"` must be `wchar_t*`, not `int*`
void test56() { int u; scanf("%ls\n", &u); }
                                      ^
fail_compilation/chkformat.d(276): Deprecation: argument `v` for format specification `"%p"` must be `void**`, not `void*`
void test57() { void* v; scanf("%p\n", v); }
                                       ^
fail_compilation/chkformat.d(277): Deprecation: argument `& u` for format specification `"%n"` must be `int*`, not `ushort*`
void test58() { ushort u; scanf("%n\n", &u); }
                                        ^
fail_compilation/chkformat.d(278): Deprecation: argument `& u` for format specification `"%hhn"` must be `byte*`, not `int*`
void test59() { int u; scanf("%hhn\n", &u); }
                                       ^
fail_compilation/chkformat.d(279): Deprecation: format specifier `"%[n"` is invalid
void test60() { int u; scanf("%[n", &u); }
                             ^
fail_compilation/chkformat.d(280): Deprecation: format specifier `"%]"` is invalid
void test61() { int u; scanf("%]\n", &u); }
                             ^
fail_compilation/chkformat.d(281): Deprecation: argument `& u` for format specification `"%90s"` must be `char*`, not `int*`
void test62() { int u; scanf("%90s\n", &u); }
                                       ^
fail_compilation/chkformat.d(282): Deprecation: argument `0L` for format specification `"%d"` must be `int*`, not `long`
void test63() { sscanf("1234", "%d\n", 0L); }
                                       ^
fail_compilation/chkformat.d(283): Deprecation: argument `0L` for format specification `"%d"` must be `int*`, not `long`
void test64() { fscanf(null, "%d\n", 0L); }
                                     ^
fail_compilation/chkformat.d(289): Deprecation: format specifier `"%K"` is invalid
void test301() { va_list vargs; vprintf("%K", vargs); }
                                        ^
fail_compilation/chkformat.d(290): Deprecation: format specifier `"%Q"` is invalid
void test302() { va_list vargs; vscanf("%Q", vargs); }
                                       ^
fail_compilation/chkformat.d(299): Deprecation: argument `p` for format specification `"%u"` must be `uint`, not `char*`
void test401() { char* p; printf("%u", p); }
                                       ^
fail_compilation/chkformat.d(300): Deprecation: argument `p` for format specification `"%d"` must be `int`, not `char*`
void test402() { char* p; printf("%d", p); }
                                       ^
fail_compilation/chkformat.d(301): Deprecation: argument `p` for format specification `"%hhu"` must be `ubyte`, not `char*`
void test403() { char* p; printf("%hhu", p); }
                                         ^
fail_compilation/chkformat.d(302): Deprecation: argument `p` for format specification `"%hhd"` must be `byte`, not `char*`
void test404() { char* p; printf("%hhd", p); }
                                         ^
fail_compilation/chkformat.d(303): Deprecation: argument `p` for format specification `"%hu"` must be `ushort`, not `char*`
void test405() { char* p; printf("%hu", p); }
                                        ^
fail_compilation/chkformat.d(304): Deprecation: argument `p` for format specification `"%hd"` must be `short`, not `char*`
void test406() { char* p; printf("%hd", p); }
                                        ^
fail_compilation/chkformat.d(305): Deprecation: argument `p` for format specification `"%lu"` must be `ulong`, not `char*`
void test407() { char* p; printf("%lu", p); }
                                        ^
fail_compilation/chkformat.d(306): Deprecation: argument `p` for format specification `"%ld"` must be `long`, not `char*`
void test408() { char* p; printf("%ld", p); }
                                        ^
fail_compilation/chkformat.d(307): Deprecation: argument `p` for format specification `"%llu"` must be `ulong`, not `char*`
void test409() { char* p; printf("%llu", p); }
                                         ^
fail_compilation/chkformat.d(308): Deprecation: argument `p` for format specification `"%lld"` must be `long`, not `char*`
void test410() { char* p; printf("%lld", p); }
                                         ^
fail_compilation/chkformat.d(309): Deprecation: argument `p` for format specification `"%ju"` must be `core.stdc.stdint.uintmax_t`, not `char*`
void test411() { char* p; printf("%ju", p); }
                                        ^
fail_compilation/chkformat.d(310): Deprecation: argument `p` for format specification `"%jd"` must be `core.stdc.stdint.intmax_t`, not `char*`
void test412() { char* p; printf("%jd", p); }
                                        ^
fail_compilation/chkformat.d(316): Deprecation: argument `p` for format specification `"%a"` must be `double`, not `char*`
void test501() { char* p; printf("%a", p); }
                                       ^
fail_compilation/chkformat.d(317): Deprecation: argument `p` for format specification `"%La"` must be `real`, not `char*`
void test502() { char* p; printf("%La", p); }
                                        ^
fail_compilation/chkformat.d(318): Deprecation: argument `p` for format specification `"%a"` must be `float*`, not `char*`
void test503() { char* p; scanf("%a", p); }
                                      ^
fail_compilation/chkformat.d(319): Deprecation: argument `p` for format specification `"%la"` must be `double*`, not `char*`
void test504() { char* p; scanf("%la", p); }
                                       ^
fail_compilation/chkformat.d(320): Deprecation: argument `p` for format specification `"%La"` must be `real*`, not `char*`
void test505() { char* p; scanf("%La", p); }
                                       ^
---
*/


import core.stdc.stdio;

// Line 100 starts here

void test1() {  printf("%*.*d\n", 0L, 1L, 2L); }
//void test2() { }
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
//void test20() { int u; char[] s; sprintf(&s[0], "%d\n", &u); }
//void test21() { int u; fprintf(null, "%d\n", &u); }
void test20() { printf("%lu", ulong.init); }
void test22() { int i; const(int)* p = &i; printf("%n", p); }

// Line 200 starts here

void test31() {  scanf("%d\n", 0L); }
void test32() {  int i; scanf("%d %d\n", &i); }
void test33() {  scanf("%d%*c\n", 0L); }
void test34() {  scanf("%3u\n", 0L); }
void test35() {  uint u; scanf("%200u%*s\n", u); }
void test36() {  scanf("%hhd\n", 3.0); }
void test37() {  scanf("%hd\n", 4); }
//void test38() {  scanf("%ld\n", 3.0); }
void test39() {  scanf("%lld\n", 4); }
void test40() { scanf("%jd\n", 5); }
void test41() { scanf("%zd\n", 6.0); }
void test42() { scanf("%td\n", 7.0); }
void test43() { scanf("%Ld\n", 0); }
void test44() { scanf("%u\n", 0); }
void test45() { scanf("%hhu\n", 0); }
void test46() { scanf("%hu\n", 0); }
//void test47() { scanf("%lu\n", 0); }
void test48() { scanf("%llu\n", 0); }
void test49() { scanf("%ju\n", 0); }
void test50() { scanf("%zu\n", 0); }
void test51() { scanf("%tu\n", 0); }
void test52() { scanf("%g\n", 8.0L); }
void test53() { scanf("%lg\n", 8.0L); }
void test54() { scanf("%Lg\n", 9.0); }
void test55() { int u; scanf("%s\n", &u); }
void test56() { int u; scanf("%ls\n", &u); }
void test57() { void* v; scanf("%p\n", v); }
void test58() { ushort u; scanf("%n\n", &u); }
void test59() { int u; scanf("%hhn\n", &u); }
void test60() { int u; scanf("%[n", &u); }
void test61() { int u; scanf("%]\n", &u); }
void test62() { int u; scanf("%90s\n", &u); }
void test63() { sscanf("1234", "%d\n", 0L); }
void test64() { fscanf(null, "%d\n", 0L); }

import core.stdc.stdarg;

// Line 300 starts here

void test301() { va_list vargs; vprintf("%K", vargs); }
void test302() { va_list vargs; vscanf("%Q", vargs); }

// TODO - C++ 11 only:
//void test() { vscanf(); }
//void test() { vfscanf(); }
//void test() { vsscanf(); }

// Line 400 starts here

void test401() { char* p; printf("%u", p); }
void test402() { char* p; printf("%d", p); }
void test403() { char* p; printf("%hhu", p); }
void test404() { char* p; printf("%hhd", p); }
void test405() { char* p; printf("%hu", p); }
void test406() { char* p; printf("%hd", p); }
void test407() { char* p; printf("%lu", p); }
void test408() { char* p; printf("%ld", p); }
void test409() { char* p; printf("%llu", p); }
void test410() { char* p; printf("%lld", p); }
void test411() { char* p; printf("%ju", p); }
void test412() { char* p; printf("%jd", p); }

// https://issues.dlang.org/show_bug.cgi?id=23247

// Line 500 starts here

void test501() { char* p; printf("%a", p); }
void test502() { char* p; printf("%La", p); }
void test503() { char* p; scanf("%a", p); }
void test504() { char* p; scanf("%la", p); }
void test505() { char* p; scanf("%La", p); }
