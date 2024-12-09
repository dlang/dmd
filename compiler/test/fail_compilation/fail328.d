/*
TEST_OUTPUT:
---
fail_compilation/fail328.d(17): Error: `@safe` function `fail328.foo` cannot call `@system` function `fail328.bar`
    bar();
       ^
fail_compilation/fail328.d(13):        `fail328.bar` is declared here
void bar();
     ^
---
*/

void bar();

@safe void foo()
{
    bar();
}
