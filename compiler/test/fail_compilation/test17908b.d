/*
TEST_OUTPUT:
---
fail_compilation/test17908b.d(15): Error: function `test17908b.foobar` cannot be used because it is annotated with `@disable`
    i(10);
     ^
---
*/
void foobar() {}
@disable void foobar(int) {}
alias i = foobar;

void main()
{
    i(10);
}
