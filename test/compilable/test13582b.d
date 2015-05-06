// REQUIRED_ARGS:
// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
compilable/test13582b.d(13): Deprecation: module test13582a is deprecated
compilable/test13582a.d(9): Deprecation: module imports.imp13582a is deprecated
compilable/imports/imp13582a.d(2): Deprecation: module imports.imp13582b is deprecated
---
*/
module test13582b;

import test13582a;
