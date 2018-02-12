/*
EXTRA_SOURCES: imports/nomodname.d
REQUIRED_ARGS: -Ifail_compilation -de
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/badimport.d(10): Error: module `nomodname` from file fail_compilation/imports/nomodname.d must be imported with 'import nomodname;'
---
*/
import imports.nomodname;
