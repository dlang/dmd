// https://github.com/dlang/dmd/issues/24131
// A C `static` global has internal linkage: invisible outside its own
// translation unit, exactly like a D `private` declaration.
/* EXTRA_SOURCES: imports/c24131.c
TEST_OUTPUT:
---
fail_compilation/importc24131.d(15): Error: undefined identifier `var`
---
*/

import c24131;

void main()
{
    var.a = 1;
}
