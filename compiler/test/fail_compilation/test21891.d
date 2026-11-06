/*
TEST_OUTPUT:
---
fail_compilation/imports/imp21891b.c(3): Error: union `U21891` already exists with an incompatible definition.
fail_compilation/imports/imp21891a.c(3):        previously declared here
fail_compilation/imports/imp21891b.c(3):        `imp21891b.U21891` is 8 bytes, `imp21891a.U21891` is 4 bytes
fail_compilation/imports/imp21891b.c(3):        `imp21891b.U21891` alignment: default
fail_compilation/imports/imp21891a.c(3):        `imp21891a.U21891` alignment: default
fail_compilation/imports/imp21891b.c(3):        C unions with the same name from different imports are merged
---
*/

// https://github.com/dlang/dmd/issues/21891
// Genuinely different-sized unions must still be rejected.

import imports.imp21891a;
import imports.imp21891b;
