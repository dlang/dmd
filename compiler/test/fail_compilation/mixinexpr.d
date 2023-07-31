/*
TEST_OUTPUT:
---
fail_compilation/mixinexpr.d-mixin-10(10): Error: unexpected token `;` after function expression
fail_compilation/mixinexpr.d-mixin-10(10):        while parsing string mixin expression `(int i) => true;`
fail_compilation/mixinexpr.d-mixin-11(11): Error: unexpected token `j` after identifier expression
fail_compilation/mixinexpr.d-mixin-11(11):        while parsing string mixin expression `i j`
---
*/
enum e = mixin("(int i) => true;");
enum f = mixin("i j");
