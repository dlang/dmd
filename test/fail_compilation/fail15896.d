// PERMUTE_ARGS:
// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail15896.d(11): Deprecation: module `imports.imp15896` member `thebar` is not accessible
fail_compilation/fail15896.d(11): Deprecation: module `imports.imp15896` member `packagebar` is not accessible
---
*/

import imports.imp15896 : thebar, packagebar;

int func()
{
    thebar +=1;
    packagebar += 1;
    return 0;
}
