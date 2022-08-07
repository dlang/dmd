/*
TEST_OUTPUT:
---
fail_compilation/lexer5.d(9): Error: number `1e-100f` is not representable as a `float`
fail_compilation/lexer5.d(9):        https://dlang.org/spec/lex.html#floatliteral
---
*/

static float f = 1e-100f;
