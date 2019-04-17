/*
REQUIRED_ARGS:
TEST_OUTPUT:
---
fail_compilation/test314.d(19): Error: undefined identifier `renamed`, did you mean import `renamed`?
fail_compilation/test314.d(20): Error: undefined identifier `bug`, did you mean alias `bug`?
fail_compilation/test314.d(22): Error: undefined identifier `renamedpkg`, did you mean import `renamedpkg`?
fail_compilation/test314.d(23): Error: undefined identifier `bugpkg`, did you mean alias `bugpkg`?
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
