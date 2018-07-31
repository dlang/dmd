/*
TEST_OUTPUT:
---
fail_compilation/diag10805.d(11): Error: delimited string must end in FOO"
fail_compilation/diag10805.d(13): Error: unterminated string constant starting at fail_compilation/diag10805.d(13)
fail_compilation/diag10805.d(13): Error: Implicit string concatenation is deprecated, use "" ~ "" instead
fail_compilation/diag10805.d(14): Error: semicolon expected following auto declaration, not `End of File`
---
*/

enum s = q"FOO
FOO
";
