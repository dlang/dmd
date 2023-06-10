/*
TEST_OUTPUT:
---
fail_compilation/b20780.d(9): Error: `@identifier` or `@(ArgumentList)` expected, not `@)`
fail_compilation/b20780.d(10): Error: `@identifier` or `@(ArgumentList)` expected, not `@,`
---
*/

void f(@){}
void g(@,){}
