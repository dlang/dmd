// https://issues.dlang.org/show_bug.cgi?id=22121
// REQUIRED_ARGS: -Ifail_compilation/imports
/*
TEST_OUTPUT:
---
fail_compilation/imports/ice22121/package2/package3/package.d(1): Error: package name 'ice22121' conflicts with usage as a module name in file fail_compilation/ice22121.d
---
*/

module ice22121;

import ice22121.package2.package3;
