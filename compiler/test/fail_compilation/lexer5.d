/*
TEST_OUTPUT:
---
fail_compilation/lexer5.d(15): Error: number `1e-100f` is not representable as a `float`
static float f = 1e-100f;
                 ^
fail_compilation/lexer5.d(15):        https://dlang.org/spec/lex.html#floatliteral
fail_compilation/lexer5.d(16): Error: number `1e-10024` is not representable as a `double`
static float f2 = 1e-10024;
                  ^
fail_compilation/lexer5.d(16):        `real` literals can be written using the `L` suffix. https://dlang.org/spec/lex.html#floatliteral
---
*/

static float f = 1e-100f;
static float f2 = 1e-10024;
