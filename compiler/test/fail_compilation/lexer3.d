/*
TEST_OUTPUT:
---
fail_compilation/lexer3.d(11): Error: unterminated token string constant starting at fail_compilation/lexer3.d(11)
static s1 = q{ asef;
            ^
fail_compilation/lexer3.d(12): Error: semicolon expected following auto declaration, not `End of File`
---
*/

static s1 = q{ asef;
