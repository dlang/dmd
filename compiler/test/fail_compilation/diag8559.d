/*
TEST_OUTPUT:
---
fail_compilation/diag8559.d(16): Error: `void` does not have a default initializer
    auto x = void.init;
             ^
fail_compilation/diag8559.d(17): Error: `function` does not have a default initializer
    auto y = typeof(foo).init;
             ^
---
*/

void foo(){}
void main()
{
    auto x = void.init;
    auto y = typeof(foo).init;
}
