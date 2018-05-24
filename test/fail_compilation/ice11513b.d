/*
REQUIRED_ARGS: fail_compilation/imports/ice11513y.d
TEST_OUTPUT:
---
fail_compilation/ice11513b.d(9): Error: module `ice11513b` from file fail_compilation/ice11513b.d conflicts with package name ice11513b
---
*/

module ice11513b;

import imports.ice11513y;
