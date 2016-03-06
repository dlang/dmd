/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/test314.d(3): Deprecation: imports.a314.renamed is not visible from module test314
fail_compilation/test314.d(4): Deprecation: imports.a314.bug is not visible from module test314
fail_compilation/test314.d(6): Deprecation: imports.b314.renamedpkg is not visible from module test314
fail_compilation/test314.d(7): Deprecation: imports.b314.bugpkg is not visible from module test314
---
*/

module test314;

import imports.a314;
import imports.b314;

#line 1
void main()
{
    renamed.bug("This should not work.\n");
    bug("This should not work.\n");

    renamedpkg.bug("This should not work.\n");
    bugpkg("This should not work.\n");
}
