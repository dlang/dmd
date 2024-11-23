/*
TEST_OUTPUT:
---
fail_compilation/ice11967.d(20): Error: use `@(attributes)` instead of `[attributes]`
[F(%g{@
^
fail_compilation/ice11967.d(20): Error: expression expected, not `%`
[F(%g{@
   ^
fail_compilation/ice11967.d(20): Error: found `g` when expecting `)`
[F(%g{@
    ^
fail_compilation/ice11967.d(20): Error: found `{` when expecting `]`
[F(%g{@
     ^
fail_compilation/ice11967.d(21): Error: `@identifier` or `@(ArgumentList)` expected, not `@End of File`
fail_compilation/ice11967.d(21): Error: declaration expected following attribute, not end of file
---
*/
[F(%g{@
