/*
TEST_OUTPUT:
---
fail_compilation/diag10805.d(10): Error: delimited string must end in FOO"
fail_compilation/diag10805.d(12): Error: unterminated string constant starting at fail_compilation/diag10805.d(12)
fail_compilation/diag10805.d(13): Error: semicolon expected following auto declaration, not 'EOF'
---
*/

enum s = q"FOO
FOO
";
