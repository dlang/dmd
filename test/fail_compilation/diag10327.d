/*
TEST_OUTPUT:
---
fail_compilation/diag10327.d(12): Error: unable to read module `test10327`
fail_compilation/diag10327.d(12):        Expected 'imports/test10327.d' or 'imports/test10327/package.d' in one of the following import paths:
fail_compilation/diag10327.d(12):        [0]: `fail_compilation`
fail_compilation/diag10327.d(12):        [1]: `$p:druntime/import$`
fail_compilation/diag10327.d(12):        [2]: `$p:phobos$`
---
*/

import imports.test10327;  // package.d missing
