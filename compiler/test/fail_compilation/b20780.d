/*
TEST_OUTPUT:
---
fail_compilation/b20780.d(16): Error: `@identifier` or `@(ArgumentList)` expected, not `@)`
void f(@){}
        ^
fail_compilation/b20780.d(17): Error: `@identifier` or `@(ArgumentList)` expected, not `@,`
void g(@,){}
        ^
fail_compilation/b20780.d(17): Error: basic type expected, not `,`
void g(@,){}
        ^
---
*/

void f(@){}
void g(@,){}
