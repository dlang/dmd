/* REQUIRED_ARGS: -verrors=simple
TEST_OUTPUT:
---
fail_compilation/c23attributes_malformed.c(14): Error: found `int` when expecting `]`
fail_compilation/c23attributes_malformed.c(14): Error: expected identifier for declarator
fail_compilation/c23attributes_malformed.c(14): Error: expected identifier for declaration
---
*/

// C23 6.7.13.2: an attribute-specifier is `[ [ attribute-list ] ]`. A sequence with a
// missing closing `]` is a parse error -- a single `[` is not a valid attribute-specifier,
// so the parser rejects it rather than silently accepting the malformed input.
[[deprecated]] int ok(void);
[[deprecated] int bad(void);
