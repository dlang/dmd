// EXTRA_FILES: imports/cstuff1.c
/* TEST_OUTPUT
---
fail_compilation/imports/cstuff1.c(5): Error: no members for `enum empty_enum`
fail_compilation/imports/cstuff1.c(6): Error: no members for anonymous enum
---
*/
import imports.cstuff1;
