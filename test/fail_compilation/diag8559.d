/*
TEST_OUTPUT:
---
fail_compilation/diag8559.d(4): Error: void does not have a default initializer
fail_compilation/diag8559.d(5): Error: function does not have a default initializer
---
*/

#line 1
void foo(){}
void main()
{
    auto x = void.init;
    auto y = typeof(foo).init;
}
