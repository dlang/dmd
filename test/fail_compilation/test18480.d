// REQUIRED_ARGS: -i
/*
TEST_OUTPUT:
---
fail_compilation/imports/test18480a.d(2): Error: `alias X = X` not allowed (with `X = TestTemplate`)
---
https://issues.dlang.org/show_bug.cgi?id=18480
*/

import imports.test18480a : TestTemplate;
