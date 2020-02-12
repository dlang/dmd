/*
TEST_OUTPUT:
---
fail_compilation/ice11967.d(13): Error: use `@(attributes)` instead of `[attributes]`
fail_compilation/ice11967.d(13): Error: expression expected, not `%`
fail_compilation/ice11967.d(13): Error: found `g` when expecting `)`
fail_compilation/ice11967.d(13): Error: found `{` when expecting `]`
fail_compilation/ice11967.d(14): Error: @identifier or @(ArgumentList) expected, not `@End of File`
fail_compilation/ice11967.d(14): Error: valid attributes are `@property`, `@safe`, `@trusted`, `@system`, `@disable`, `@nogc`
fail_compilation/ice11967.d(14): Error: declaration expected following attribute, not end of file
---
*/
[F(%g{@
