/*
REQUIRED_ARGS: -w
TEST_OUTPUT:
----
----
*/

pragma(lint, unusedParams):

class A
{
    void foo(int x) {}
}

void main()
{
    auto a = new A();
    a.foo(1);
}
