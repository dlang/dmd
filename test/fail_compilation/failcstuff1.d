// EXTRA_FILES: imports/cstuff1.c
/* TEST_OUTPUT
---
fail_compilation/imports/cstuff1.c(101): Error: attributes should be specified before the function definition
fail_compilation/imports/cstuff1.c(200): Error: no members for `enum E21962`
fail_compilation/imports/cstuff1.c(201): Error: no members for anonymous enum
fail_compilation/imports/cstuff1.c(303): Error: storage class not allowed in specifier-qualified-list
fail_compilation/imports/cstuff1.c(304): Error: storage class not allowed in specifier-qualified-list
fail_compilation/imports/cstuff1.c(305): Error: storage class not allowed in specifier-qualified-list
fail_compilation/imports/cstuff1.c(306): Error: storage class not allowed in specifier-qualified-list
fail_compilation/imports/cstuff1.c(307): Error: storage class not allowed in specifier-qualified-list
fail_compilation/imports/cstuff1.c(308): Error: storage class not allowed in specifier-qualified-list
fail_compilation/imports/cstuff1.c(401): Error: identifier or `(` expected
fail_compilation/imports/cstuff1.c(402): Error: identifier or `(` expected
fail_compilation/imports/cstuff1.c(403): Error: identifier or `(` expected
fail_compilation/imports/cstuff1.c(408): Error: identifier or `(` expected
fail_compilation/imports/cstuff1.c(409): Error: identifier or `(` expected
fail_compilation/imports/cstuff1.c(410): Error: identifier or `(` expected
---
*/
import imports.cstuff1;
