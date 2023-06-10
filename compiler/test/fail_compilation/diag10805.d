/*
TEST_OUTPUT:
---
fail_compilation/diag10805.d(12): Error: delimited string must end in `FOO"`
fail_compilation/diag10805.d(14): Error: unterminated string constant starting at fail_compilation/diag10805.d(14)
fail_compilation/diag10805.d(15): Error: semicolon expected following auto declaration, not `End of File`
---
*/



enum s = q"FOO
FOO
";
