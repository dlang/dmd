/*
EXTRA_FILES: imports/a314.d imports/b314.d imports/c314.d
TEST_OUTPUT:
---
fail_compilation/test314.d(27): Error: undefined identifier `renamed`
    renamed.bug("This should not work.\n");
    ^
fail_compilation/test314.d(28): Error: undefined identifier `bug`
    bug("This should not work.\n");
    ^
fail_compilation/test314.d(30): Error: undefined identifier `renamedpkg`
    renamedpkg.bug("This should not work.\n");
    ^
fail_compilation/test314.d(31): Error: undefined identifier `bugpkg`
    bugpkg("This should not work.\n");
    ^
---
*/

module test314;

import imports.a314;
import imports.b314;

void main()
{
    renamed.bug("This should not work.\n");
    bug("This should not work.\n");

    renamedpkg.bug("This should not work.\n");
    bugpkg("This should not work.\n");
}
