/*
REQUIRED_ARGS: -Ifail_compilation/imports
EXTRA_FILES: imports/pkg17699/datetime.d imports/pkg17699/datetime/package.d
TEST_OUTPUT:
---
fail_compilation/test17699.d(13): Error: module `datetime` is both a source file and folder with package.d
---
*/

// https://issues.dlang.org/show_bug.cgi?id=17699
// Issue 17699 - Importing a module that has both modulename.d and modulename/package.d should be an error

import pkg17699.datetime;
