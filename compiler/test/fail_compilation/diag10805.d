/*
TEST_OUTPUT:
---
fail_compilation/diag10805.d(18): Error: delimited string must end in `FOO"`
enum s = q"FOO
         ^
fail_compilation/diag10805.d(20): Error: unterminated string constant starting at fail_compilation/diag10805.d(20)
";
^
fail_compilation/diag10805.d(20): Error: implicit string concatenation is error-prone and disallowed in D
";
^
fail_compilation/diag10805.d(20):        Use the explicit syntax instead (concatenating literals is `@nogc`): "" ~ ""
fail_compilation/diag10805.d(21): Error: semicolon expected following auto declaration, not `End of File`
---
*/

enum s = q"FOO
FOO
";
