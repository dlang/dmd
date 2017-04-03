/*
TEST_OUTPUT:
---
fail_compilation/fail15896.d(8): Error: module imports.imp15896 member 'thebar' is private
---
*/

import imports.imp15896 : thebar;

int func()
{
    thebar +=1;
    return 0;
}
