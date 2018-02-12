/*
EXTRA_SOURCES: imports/incompletemodname.d
REQUIRED_ARGS: -Ifail_compilation -de
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/badimport2.d(10): Error: module `incompletemodname` from file fail_compilation/imports/incompletemodname.d must be imported with 'import incompletemodname;'
---
*/
import imports.incompletemodname;
