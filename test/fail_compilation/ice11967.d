/*
TEST_OUTPUT:
---
fail_compilation/ice11967.d(18): Error: use `@(attributes)` instead of `[attributes]`
fail_compilation/ice11967.d(18): Error: expression expected, not `%`
fail_compilation/ice11967.d(18): Error: found `g` when expecting `,`
fail_compilation/ice11967.d(19): Error: @identifier or @(ArgumentList) expected, not `@End of File`
fail_compilation/ice11967.d(19): Error: valid attributes are `@property`, `@safe`, `@trusted`, `@system`, `@disable`, `@nogc`
fail_compilation/ice11967.d(19): Error: basic type expected, not `End of File`
fail_compilation/ice11967.d(19): Error: found `End of File` when expecting `}` following compound statement
fail_compilation/ice11967.d(19): Error: found `End of File` when expecting `,`
fail_compilation/ice11967.d(19): Error: found `End of File` when expecting `)`
fail_compilation/ice11967.d(19): Error: found `End of File` when expecting `,`
fail_compilation/ice11967.d(19): Error: found `End of File` when expecting `]`
fail_compilation/ice11967.d(19): Error: declaration expected following attribute, not end of file
---
*/
[F(%g{@
