/*
TEST_OUTPUT:
---
fail_compilation/noreturnval.d(16): Error: type `noreturn` has no value
fail_compilation/noreturnval.d(18): Error: type `int` is not an expression
fail_compilation/noreturnval.d(19): Error: type `int` is not an expression
fail_compilation/noreturnval.d(20): Error: type `noreturn` is not an expression
fail_compilation/noreturnval.d(21): Error: type `noreturn` is not an expression
fail_compilation/noreturnval.d(22): Error: type `noreturn` is not an expression
fail_compilation/noreturnval.d(28): Error: type `noreturn` is not an expression
fail_compilation/noreturnval.d(23): Error: template instance `noreturnval.ft!(noreturn)` error instantiating
---
*/
void f()
{
    auto v = noreturn;
    int e;
    e = int + 5;
    e = 5 + int;
    e = 5 + noreturn;
    e = noreturn + 5;
    e = noreturn + e;
    e = ft!noreturn();
}

int ft(T)()
{
    return T + 0;
}
