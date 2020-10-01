/*
TEST_OUTPUT:
---
fail_compilation/b20780.d(12): Error: @identifier or @(ArgumentList) expected, not `@)`
fail_compilation/b20780.d(12): Error: valid attributes are `@property`, `@safe`, `@trusted`, `@system`, `@disable`, `@nogc`, `@nodiscard`
fail_compilation/b20780.d(13): Error: @identifier or @(ArgumentList) expected, not `@,`
fail_compilation/b20780.d(13): Error: valid attributes are `@property`, `@safe`, `@trusted`, `@system`, `@disable`, `@nogc`, `@nodiscard`
fail_compilation/b20780.d(13): Error: basic type expected, not `,`
---
*/

void f(@){}
void g(@,){}
