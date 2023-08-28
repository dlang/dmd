/*
TEST_OUTPUT:
---
fail_compilation/noreturnval.d(17): Error: type `noreturn` has no value
fail_compilation/noreturnval.d(19): Error: type `int` has no value
fail_compilation/noreturnval.d(20): Error: type `int` has no value
fail_compilation/noreturnval.d(21): Error: type `noreturn` has no value
fail_compilation/noreturnval.d(22): Error: type `noreturn` has no value
fail_compilation/noreturnval.d(23): Error: type `noreturn` has no value
fail_compilation/noreturnval.d(24): Error: incompatible types for `(noreturn) == (1)`: cannot use `==` with types
fail_compilation/noreturnval.d(30): Error: type `noreturn` has no value
fail_compilation/noreturnval.d(25): Error: template instance `noreturnval.ft!(noreturn)` error instantiating
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
    e = noreturn == 1;
    e = ft!noreturn();
}

int ft(T)()
{
    return T + 0;
}
