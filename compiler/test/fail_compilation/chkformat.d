/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/chkformat.d(101): Deprecation: width argument `0L` of type `long` does not match format specification
fail_compilation/chkformat.d(101):        `"%*.*d"` requires `int`
fail_compilation/chkformat.d(101): Deprecation: precision argument `1L` of type `long` does not match format specification
fail_compilation/chkformat.d(101):        `"%*.*d"` requires `int`
fail_compilation/chkformat.d(101): Deprecation: argument `2L` of type `long` does not match format specification
fail_compilation/chkformat.d(101):        `"%*.*d"` requires `int`
fail_compilation/chkformat.d(101):        `long` may be formatted with `"%lld"`
fail_compilation/chkformat.d(104): Deprecation: argument `4` of type `int` does not match format specification
fail_compilation/chkformat.d(104):        `"%lld"` requires `long`
fail_compilation/chkformat.d(104):        `int` may be formatted with `"%d"`
fail_compilation/chkformat.d(105): Deprecation: argument `5` of type `int` does not match format specification
fail_compilation/chkformat.d(105):        `"%jd"` requires `core.stdc.stdint.intmax_t`
fail_compilation/chkformat.d(105):        `int` may be formatted with `"%d"`
fail_compilation/chkformat.d(106): Deprecation: argument `6.0` of type `double` does not match format specification
fail_compilation/chkformat.d(106):        `"%zd"` requires `size_t`
fail_compilation/chkformat.d(106):        `double` may be formatted with `"%g"`
fail_compilation/chkformat.d(107): Deprecation: argument `7.0` of type `double` does not match format specification
fail_compilation/chkformat.d(107):        `"%td"` requires `ptrdiff_t`
fail_compilation/chkformat.d(107):        `double` may be formatted with `"%g"`
fail_compilation/chkformat.d(108): Deprecation: argument `8.0L` of type `real` does not match format specification
fail_compilation/chkformat.d(108):        `"%g"` requires `double`
fail_compilation/chkformat.d(108):        `real` may be formatted with `"%Lg"`
fail_compilation/chkformat.d(109): Deprecation: argument `9.0` of type `double` does not match format specification
fail_compilation/chkformat.d(109):        `"%Lg"` requires `real`
fail_compilation/chkformat.d(109):        `double` may be formatted with `"%g"`
fail_compilation/chkformat.d(110): Deprecation: argument `10` of type `int` does not match format specification
fail_compilation/chkformat.d(110):        `"%p"` requires `void*`
fail_compilation/chkformat.d(110):        `int` may be formatted with `"%d"`
fail_compilation/chkformat.d(111): Deprecation: argument `& u` of type `uint*` does not match format specification
fail_compilation/chkformat.d(111):        `"%n"` requires `int*`
fail_compilation/chkformat.d(111):        `uint*` may be formatted with `"%p"`
fail_compilation/chkformat.d(113): Deprecation: argument `& u` of type `int*` does not match format specification
fail_compilation/chkformat.d(113):        `"%lln"` requires `long*`
fail_compilation/chkformat.d(113):        `int*` may be formatted with `"%p"`
fail_compilation/chkformat.d(114): Deprecation: argument `& u` of type `int*` does not match format specification
fail_compilation/chkformat.d(114):        `"%hn"` requires `short*`
fail_compilation/chkformat.d(114):        `int*` may be formatted with `"%p"`
fail_compilation/chkformat.d(115): Deprecation: argument `& u` of type `int*` does not match format specification
fail_compilation/chkformat.d(115):        `"%hhn"` requires `byte*`
fail_compilation/chkformat.d(115):        `int*` may be formatted with `"%p"`
fail_compilation/chkformat.d(116): Deprecation: argument `16L` of type `long` does not match format specification
fail_compilation/chkformat.d(116):        `"%c"` requires `char`
fail_compilation/chkformat.d(116):        `long` may be formatted with `"%lld"`
fail_compilation/chkformat.d(117): Deprecation: argument `17L` of type `long` does not match format specification
fail_compilation/chkformat.d(117):        `"%c"` requires `char`
fail_compilation/chkformat.d(117):        `long` may be formatted with `"%lld"`
fail_compilation/chkformat.d(118): Deprecation: argument `& u` of type `int*` does not match format specification
fail_compilation/chkformat.d(118):        `"%s"` requires `char*`
fail_compilation/chkformat.d(118):        `int*` may be formatted with `"%p"`
fail_compilation/chkformat.d(119): Deprecation: argument `& u` of type `int*` does not match format specification
fail_compilation/chkformat.d(119):        `"%ls"` requires `wchar_t*`
fail_compilation/chkformat.d(119):        `int*` may be formatted with `"%p"`
fail_compilation/chkformat.d(122): Deprecation: argument `p` of type `const(int)*` does not match format specification
fail_compilation/chkformat.d(122):        `"%n"` requires `int*`
fail_compilation/chkformat.d(122):        `const(int)*` may be formatted with `"%p"`
fail_compilation/chkformat.d(201): Deprecation: argument `0L` of type `long` does not match format specification
fail_compilation/chkformat.d(201):        `"%d"` requires `int*`
fail_compilation/chkformat.d(202): Deprecation: more format specifiers than 1 arguments
fail_compilation/chkformat.d(203): Deprecation: argument `0L` of type `long` does not match format specification
fail_compilation/chkformat.d(203):        `"%d"` requires `int*`
fail_compilation/chkformat.d(204): Deprecation: argument `0L` of type `long` does not match format specification
fail_compilation/chkformat.d(204):        `"%3u"` requires `uint*`
fail_compilation/chkformat.d(205): Deprecation: argument `u` of type `uint` does not match format specification
fail_compilation/chkformat.d(205):        `"%200u"` requires `uint*`
fail_compilation/chkformat.d(206): Deprecation: argument `3.0` of type `double` does not match format specification
fail_compilation/chkformat.d(206):        `"%hhd"` requires `byte*`
fail_compilation/chkformat.d(207): Deprecation: argument `4` of type `int` does not match format specification
fail_compilation/chkformat.d(207):        `"%hd"` requires `short*`
fail_compilation/chkformat.d(209): Deprecation: argument `4` of type `int` does not match format specification
fail_compilation/chkformat.d(209):        `"%lld"` requires `long*`
fail_compilation/chkformat.d(210): Deprecation: argument `5` of type `int` does not match format specification
fail_compilation/chkformat.d(210):        `"%jd"` requires `core.stdc.stdint.intmax_t*`
fail_compilation/chkformat.d(211): Deprecation: argument `6.0` of type `double` does not match format specification
fail_compilation/chkformat.d(211):        `"%zd"` requires `size_t*`
fail_compilation/chkformat.d(212): Deprecation: argument `7.0` of type `double` does not match format specification
fail_compilation/chkformat.d(212):        `"%td"` requires `ptrdiff_t*`
fail_compilation/chkformat.d(213): Deprecation: format specifier `"%Ld"` is invalid
fail_compilation/chkformat.d(214): Deprecation: argument `0` of type `int` does not match format specification
fail_compilation/chkformat.d(214):        `"%u"` requires `uint*`
fail_compilation/chkformat.d(215): Deprecation: argument `0` of type `int` does not match format specification
fail_compilation/chkformat.d(215):        `"%hhu"` requires `ubyte*`
fail_compilation/chkformat.d(216): Deprecation: argument `0` of type `int` does not match format specification
fail_compilation/chkformat.d(216):        `"%hu"` requires `ushort*`
fail_compilation/chkformat.d(218): Deprecation: argument `0` of type `int` does not match format specification
fail_compilation/chkformat.d(218):        `"%llu"` requires `ulong*`
fail_compilation/chkformat.d(219): Deprecation: argument `0` of type `int` does not match format specification
fail_compilation/chkformat.d(219):        `"%ju"` requires `core.stdc.stdint.uintmax_t*`
fail_compilation/chkformat.d(220): Deprecation: argument `0` of type `int` does not match format specification
fail_compilation/chkformat.d(220):        `"%zu"` requires `size_t*`
fail_compilation/chkformat.d(221): Deprecation: argument `0` of type `int` does not match format specification
fail_compilation/chkformat.d(221):        `"%tu"` requires `ptrdiff_t*`
fail_compilation/chkformat.d(222): Deprecation: argument `8.0L` of type `real` does not match format specification
fail_compilation/chkformat.d(222):        `"%g"` requires `float*`
fail_compilation/chkformat.d(223): Deprecation: argument `8.0L` of type `real` does not match format specification
fail_compilation/chkformat.d(223):        `"%lg"` requires `double*`
fail_compilation/chkformat.d(224): Deprecation: argument `9.0` of type `double` does not match format specification
fail_compilation/chkformat.d(224):        `"%Lg"` requires `real*`
fail_compilation/chkformat.d(225): Deprecation: argument `& u` of type `int*` does not match format specification
fail_compilation/chkformat.d(225):        `"%s"` requires `char*`
fail_compilation/chkformat.d(225):        `int*` may be formatted with `"%d"`
fail_compilation/chkformat.d(226): Deprecation: argument `& u` of type `int*` does not match format specification
fail_compilation/chkformat.d(226):        `"%ls"` requires `wchar_t*`
fail_compilation/chkformat.d(226):        `int*` may be formatted with `"%d"`
fail_compilation/chkformat.d(227): Deprecation: argument `v` of type `void*` does not match format specification
fail_compilation/chkformat.d(227):        `"%p"` requires `void**`
fail_compilation/chkformat.d(228): Deprecation: argument `& u` of type `ushort*` does not match format specification
fail_compilation/chkformat.d(228):        `"%n"` requires `int*`
fail_compilation/chkformat.d(228):        `ushort*` may be formatted with `"%hu"`
fail_compilation/chkformat.d(229): Deprecation: argument `& u` of type `int*` does not match format specification
fail_compilation/chkformat.d(229):        `"%hhn"` requires `byte*`
fail_compilation/chkformat.d(229):        `int*` may be formatted with `"%d"`
fail_compilation/chkformat.d(230): Deprecation: format specifier `"%[n"` is invalid
fail_compilation/chkformat.d(231): Deprecation: format specifier `"%]"` is invalid
fail_compilation/chkformat.d(232): Deprecation: argument `& u` of type `int*` does not match format specification
fail_compilation/chkformat.d(232):        `"%90s"` requires `char*`
fail_compilation/chkformat.d(232):        `int*` may be formatted with `"%d"`
fail_compilation/chkformat.d(233): Deprecation: argument `0L` of type `long` does not match format specification
fail_compilation/chkformat.d(233):        `"%d"` requires `int*`
fail_compilation/chkformat.d(234): Deprecation: argument `0L` of type `long` does not match format specification
fail_compilation/chkformat.d(234):        `"%d"` requires `int*`
---
*/


import core.stdc.stdio;

#line 100

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
void test22() { int i; const(int)* p = &i; printf("%n", p); }

#line 200

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

/* TEST_OUTPUT:
---
fail_compilation/chkformat.d(301): Deprecation: format specifier `"%K"` is invalid
fail_compilation/chkformat.d(302): Deprecation: format specifier `"%Q"` is invalid
---
*/

import core.stdc.stdarg;

#line 300

void test301() { va_list vargs; vprintf("%K", vargs); }
void test302() { va_list vargs; vscanf("%Q", vargs); }

// TODO - C++ 11 only:
//void test() { vscanf(); }
//void test() { vfscanf(); }
//void test() { vsscanf(); }

/* TEST_OUTPUT:
---
fail_compilation/chkformat.d(401): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat.d(401):        `"%u"` requires `uint`
fail_compilation/chkformat.d(401):        `char*` may be formatted with `"%s"`
fail_compilation/chkformat.d(402): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat.d(402):        `"%d"` requires `int`
fail_compilation/chkformat.d(402):        `char*` may be formatted with `"%s"`
fail_compilation/chkformat.d(403): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat.d(403):        `"%hhu"` requires `ubyte`
fail_compilation/chkformat.d(403):        `char*` may be formatted with `"%s"`
fail_compilation/chkformat.d(404): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat.d(404):        `"%hhd"` requires `byte`
fail_compilation/chkformat.d(404):        `char*` may be formatted with `"%s"`
fail_compilation/chkformat.d(405): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat.d(405):        `"%hu"` requires `ushort`
fail_compilation/chkformat.d(405):        `char*` may be formatted with `"%s"`
fail_compilation/chkformat.d(406): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat.d(406):        `"%hd"` requires `short`
fail_compilation/chkformat.d(406):        `char*` may be formatted with `"%s"`
fail_compilation/chkformat.d(409): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat.d(409):        `"%llu"` requires `ulong`
fail_compilation/chkformat.d(409):        `char*` may be formatted with `"%s"`
fail_compilation/chkformat.d(410): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat.d(410):        `"%lld"` requires `long`
fail_compilation/chkformat.d(410):        `char*` may be formatted with `"%s"`
fail_compilation/chkformat.d(411): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat.d(411):        `"%ju"` requires `core.stdc.stdint.uintmax_t`
fail_compilation/chkformat.d(411):        `char*` may be formatted with `"%s"`
fail_compilation/chkformat.d(412): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat.d(412):        `"%jd"` requires `core.stdc.stdint.intmax_t`
fail_compilation/chkformat.d(412):        `char*` may be formatted with `"%s"`
---
*/

#line 400

void test401() { char* p; printf("%u", p); }
void test402() { char* p; printf("%d", p); }
void test403() { char* p; printf("%hhu", p); }
void test404() { char* p; printf("%hhd", p); }
void test405() { char* p; printf("%hu", p); }
void test406() { char* p; printf("%hd", p); }
//void test407() { char* p; printf("%lu", p); }  // moved to chkformat_clong.d
//void test408() { char* p; printf("%ld", p); }  // moved to chkformat_clong.d
void test409() { char* p; printf("%llu", p); }
void test410() { char* p; printf("%lld", p); }
void test411() { char* p; printf("%ju", p); }
void test412() { char* p; printf("%jd", p); }

/* https://issues.dlang.org/show_bug.cgi?id=23247
TEST_OUTPUT:
---
fail_compilation/chkformat.d(501): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat.d(501):        `"%a"` requires `double`
fail_compilation/chkformat.d(501):        `char*` may be formatted with `"%s"`
fail_compilation/chkformat.d(502): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat.d(502):        `"%La"` requires `real`
fail_compilation/chkformat.d(502):        `char*` may be formatted with `"%s"`
fail_compilation/chkformat.d(503): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat.d(503):        `"%a"` requires `float*`
fail_compilation/chkformat.d(503):        `char*` may be formatted with `"%s"`
fail_compilation/chkformat.d(504): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat.d(504):        `"%la"` requires `double*`
fail_compilation/chkformat.d(504):        `char*` may be formatted with `"%s"`
fail_compilation/chkformat.d(505): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat.d(505):        `"%La"` requires `real*`
fail_compilation/chkformat.d(505):        `char*` may be formatted with `"%s"`
---
*/
#line 500

void test501() { char* p; printf("%a", p); }
void test502() { char* p; printf("%La", p); }
void test503() { char* p; scanf("%a", p); }
void test504() { char* p; scanf("%la", p); }
void test505() { char* p; scanf("%La", p); }
