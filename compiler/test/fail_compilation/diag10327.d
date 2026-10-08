/*
TEST_OUTPUT:
---
fail_compilation/diag10327.d(11): Error: unable to read module `test10327`
fail_compilation/diag10327.d(11):        Expected 'imports/test10327.d' or 'imports/test10327/package.d' in one of the following import paths:
import path[0] = fail_compilation
import path[1] = $p:druntime/import$
---
*/

import imports.test10327;  // package.d missing
