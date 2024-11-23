/*
EXTRA_FILES: imports/fail355.d
TEST_OUTPUT:
---
fail_compilation/fail355.d(11): Error: module `imports.fail355` import `nonexistent` not found
import imports.fail355 : nonexistent;
       ^
---
*/

import imports.fail355 : nonexistent;
