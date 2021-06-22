// EXTRA_FILES: imports/cstuff1.c
/* TEST_OUTPUT
---
fail_compilation/imports/cstuff1.c(101): Error: attributes should be specified before the function definition
fail_compilation/imports/cstuff1.c(200): Error: no members for `enum E21962`
fail_compilation/imports/cstuff1.c(201): Error: no members for anonymous enum
fail_compilation/imports/cstuff1.c(252): Error: `;` or `,` expected
fail_compilation/imports/cstuff1.c(253): Error: `void` has no value
fail_compilation/imports/cstuff1.c(253): Error: missing comma
fail_compilation/imports/cstuff1.c(253): Error: `;` or `,` expected
fail_compilation/imports/cstuff1.c(254): Error: empty struct-declaration-list for `struct Anonymous`
fail_compilation/imports/cstuff1.c(257): Error: identifier not allowed in abstract-declarator
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
fail_compilation/imports/cstuff1.c(451): Error: illegal type combination
fail_compilation/imports/cstuff1.c(502): Error: found `2` when expecting `:`
fail_compilation/imports/cstuff1.c(502): Error: found `:` instead of statement
fail_compilation/imports/cstuff1.c(553): Error: left operand is not assignable
fail_compilation/imports/cstuff1.c(554): Error: left operand is not assignable
fail_compilation/imports/cstuff1.c(555): Error: expression expected, not `short`
fail_compilation/imports/cstuff1.c(555): Error: increment operand is not assignable
fail_compilation/imports/cstuff1.c(555): Error: found `3` when expecting `;` following statement
fail_compilation/imports/cstuff1.c(556): Error: decrement operand is not assignable
fail_compilation/imports/cstuff1.c(557): Error: increment operand is not assignable
fail_compilation/imports/cstuff1.c(558): Error: decrement operand is not assignable
fail_compilation/imports/cstuff1.c(559): Error: cannot take address of unary operand
fail_compilation/imports/cstuff1.c(603): Error: expression expected, not `short`
fail_compilation/imports/cstuff1.c(603): Error: increment operand is not assignable
fail_compilation/imports/cstuff1.c(603): Error: found `var` when expecting `;` following statement
fail_compilation/imports/cstuff1.c(604): Error: expression expected, not `long`
fail_compilation/imports/cstuff1.c(604): Error: found `long` when expecting `)`
fail_compilation/imports/cstuff1.c(604): Error: decrement operand is not assignable
fail_compilation/imports/cstuff1.c(604): Error: found `)` when expecting `;` following statement
---
*/
import imports.cstuff1;
