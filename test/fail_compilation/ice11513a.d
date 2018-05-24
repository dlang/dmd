/*
REQUIRED_ARGS: fail_compilation/imports/ice11513x.d
TEST_OUTPUT:
---
fail_compilation/ice11513a.d(9): Error: module `ice11513a` from file fail_compilation/ice11513a.d conflicts with package name ice11513a
---
*/

module ice11513a;

import imports.ice11513x;
