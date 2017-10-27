/*
TEST_OUTPUT:
---
fail_compilation/test17908a.d(10): Error: function test17908a.foo is not callable because it is annotated with @disable
---
*/

@disable void foo();
@disable void foo(int) {}
alias g = foo;

void main()
{
    g(10);
}
