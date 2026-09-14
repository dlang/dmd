/*
TEST_OUTPUT:
---
fail_compilation/lexer23853.d(14): Error: unterminated /+ +/ comment
fail_compilation/lexer23853.d(16): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/lexer23853.d(13):        unmatched `{`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=23853

int main()
{
    /+ string s = "no closing quote
}
