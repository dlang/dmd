/*
TEST_OUTPUT:
---
fail_compilation/lexer2.d(15): Error: odd number (3) of hex characters in hex string
fail_compilation/lexer2.d(16): Error: non-hex character 'G' in hex string
fail_compilation/lexer2.d(17): Error: identifier expected for heredoc, not 2070L
fail_compilation/lexer2.d(19): Error: heredoc rest of line should be blank
fail_compilation/lexer2.d(21): Error: unterminated delimited string constant starting at fail_compilation/lexer2.d(21)
fail_compilation/lexer2.d(23): Error: semicolon expected following auto declaration, not 'EOF'
---
*/

// https://dlang.dawg.eu/coverage/src/lexer.c.gcov.html

static s1 = x"123";
static s2 = x"123G";
static s3 = q"__VERSION__
 _";
static s4 = q"here notblank
here";
static s5 = q"here
";
