// REQUIRED_ARGS: -i
/*
TEST_OUTPUT:
---
fail_compilation/imports/test18480a.d(2): Error: `alias TestTemplate = TestTemplate;` cannot alias itself, use a qualified name to create an overload set
fail_compilation/imports/test18480a.d(2): Error: alias `test18480a.TestTemplate` conflicts with alias `test18480a.TestTemplate` at fail_compilation/imports/test18480a.d(1)
---
https://issues.dlang.org/show_bug.cgi?id=18480
*/

import imports.test18480a : TestTemplate;
