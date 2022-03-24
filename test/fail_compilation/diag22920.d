/*
REQUIRED_ARGS: -Ifail_compilation/diag22920.d -Ithis/folder/doesnt/exist
TEST_OUTPUT:
----
fail_compilation/diag22920.d(15): Error: unable to read module `foo`
fail_compilation/diag22920.d(15):        Expected 'foo.d' or 'foo/package.d' in one of the following import paths:
fail_compilation/diag22920.d(15):        [0]: `fail_compilation`
fail_compilation/diag22920.d(15):        [1]: `fail_compilation/diag22920.d` (not a directory)
fail_compilation/diag22920.d(15):        [2]: `this/folder/doesnt/exist` (path not found)
fail_compilation/diag22920.d(15):        [3]: `$p:druntime/import$`
fail_compilation/diag22920.d(15):        [4]: `$p:phobos$`
----
*/

import foo;
