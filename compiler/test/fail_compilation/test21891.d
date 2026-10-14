/*
TEST_OUTPUT:
---
---
*/

// https://github.com/dlang/dmd/issues/21891
// Genuinely different-sized unions must still be rejected.

import imports.imp21891a;
import imports.imp21891b;
