// Test printf format checking for C long size-dependent cases (64-bit: long = 8 bytes)
/*
REQUIRED_ARGS: -de
DISABLED: win32 win64 freebsd32 openbsd32 linux32 osx32
TEST_OUTPUT:
---
fail_compilation/chkformat_clong.d(21): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat_clong.d(21):        `"%lu"` requires `ulong`
fail_compilation/chkformat_clong.d(21):        `char*` may be formatted with `"%s"`
fail_compilation/chkformat_clong.d(22): Deprecation: argument `p` of type `char*` does not match format specification
fail_compilation/chkformat_clong.d(22):        `"%ld"` requires `long`
fail_compilation/chkformat_clong.d(22):        `char*` may be formatted with `"%s"`
---
*/

import core.stdc.stdio;
#line 20
void test_lu_ulong()    { printf("%lu", ulong.init); } // no error: ulong matches %lu on 64-bit
void test_lu_charstar() { char* p; printf("%lu", p); }
void test_ld_charstar() { char* p; printf("%ld", p); }
