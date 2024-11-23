/*
EXTRA_FILES: imports/imp20709.d
TEST_OUTPUT:
---
fail_compilation/ice20709.d(12): Error: module `imp20709` import `Point` not found
import imports.imp20709 : Point;
       ^
---
*/
module ice20709;

import imports.imp20709 : Point;

immutable Point aPoint = somePoint;

Point somePoint() {}
