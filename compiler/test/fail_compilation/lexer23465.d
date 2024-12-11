/*
TEST_OUTPUT:
---
fail_compilation/lexer23465.d(29): Error: character 0x1f37a is not allowed as a continue character in an identifier
    x🍺,
    ^
fail_compilation/lexer23465.d(29): Error: character 0x1f37a is not a valid token
    x🍺,
     ^
fail_compilation/lexer23465.d(30): Error: character '\' is not a valid token
    3\,
     ^
fail_compilation/lexer23465.d(31): Error: unterminated /+ +/ comment
    5, /+
       ^
fail_compilation/lexer23465.d(32): Error: found `End of File` instead of array initializer
fail_compilation/lexer23465.d(32): Error: semicolon needed to end declaration of `arr`, instead of `End of File`
fail_compilation/lexer23465.d(27):        `arr` declared here
int[] arr = [
      ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=23465
// Invalid token error points to wrong line

int[] arr = [
	0,
    x🍺,
    3\,
    5, /+
