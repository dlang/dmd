// REQUIRED_ARGS:
// PERMUTE_ARGS:
/* TEST_OUTPUT:
---
compilable/test13582c.d(10): Deprecation: module imports.imp13582a is deprecated
compilable/imports/imp13582a.d(2): Deprecation: module imports.imp13582b is deprecated
compilable/test13582c.d(11): Deprecation: module imports.imp13582b is deprecated
---
*/
import imports.imp13582a;
import imports.imp13582b;
