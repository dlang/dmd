/*
C1OMPILED_IMPORTS: imports/wrongpkgname.d
REQUIRED_ARGS: -Ifail_compilation
PERMUTE_ARGS:
TEST_OUTPUT:
---
compilable/badimport.d(10): Deprecation: module `wrongpkg.wrongpkgname` from file compilable/imports/wrongpkgname.d must be imported with 'import wrongpkg.wrongpkgname;'
---
*/
import imports.wrongpkgname;
