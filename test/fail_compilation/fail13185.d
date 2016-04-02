/*
REQUIRED_ARGS: -o-
TEST_OUTPUT:
---
fail_compilation/fail13185.d(31): Error: function 'fail13185.func' called with 'func(3)' does not pass precondition assert(x > 5)
fail_compilation/fail13185.d(32): Error: function 'fail13185.divide' called with 'divide(9, 0)' does not pass precondition assert(y != 0)
---
*/

void func(int x)
in
{
    assert(x > 5);
}
body
{
}

int divide(int x, int y)
in
{
    assert(y != 0);
}
body
{
    return x / y;
}

void main()
{
    func(3);
    assert(divide(9, 0) != 0);
}
