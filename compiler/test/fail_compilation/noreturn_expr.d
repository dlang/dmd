/*
TEST_OUTPUT:
---
fail_compilation/noreturn_expr.d(12): Error: type `noreturn` is not an expression
    return e + 0;
           ^
---
*/

int v(e)()
{
    return e + 0;
}

int main()
{
    return v!(noreturn)();
}
