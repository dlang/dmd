// Test printf format checking for C long size-dependent cases (32-bit / Windows: long = 4 bytes)
/*
REQUIRED_ARGS: -de
DISABLED: linux64 freebsd64 openbsd64 osx64
TEST_OUTPUT:
---
fail_compilation/chkformat_clong_smalllong.d(20): Deprecation: argument `0LU` of type `ulong` does not match format specification
fail_compilation/chkformat_clong_smalllong.d(20):        `"%lu"` requires `uint`
fail_compilation/chkformat_clong_smalllong.d(20):        `ulong` may be formatted with `"%llu"`
fail_compilation/chkformat_clong_smalllong.d(20):        C `long` is 4 bytes on your system
fail_compilation/chkformat_clong_smalllong.d(21): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat_clong_smalllong.d(21):        `"%lu"` requires `uint`
fail_compilation/chkformat_clong_smalllong.d(21):        `char*` may be formatted with `"%s"`
fail_compilation/chkformat_clong_smalllong.d(22): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat_clong_smalllong.d(22):        `"%ld"` requires `int`
fail_compilation/chkformat_clong_smalllong.d(22):        `char*` may be formatted with `"%s"`
---
*/

import core.stdc.stdio;
#line 20
void test_lu_ulong()    { printf("%lu", ulong.init); }
void test_lu_charstar() { char* p; printf("%lu", p); }
void test_ld_charstar() { char* p; printf("%ld", p); }
