// EXTRA_FILES: imports/cstuff1.c
/* TEST_OUTPUT
---
fail_compilation/imports/cstuff1.c(101): Error: attributes should be specified before the function definition
fail_compilation/imports/cstuff1.c(200): Error: no members for `enum E21962`
fail_compilation/imports/cstuff1.c(201): Error: no members for anonymous enum
---
*/
import imports.cstuff1;
