/*
TEST_OUTPUT:
---
fail_compilation/faildg.d(11): Error: delegate `faildg.__dgliteral$n$` is a nested function and cannot be accessed from `faildg.fun`
---
*/
enum dg = delegate {};

void fun()
{
    auto var = dg;
}
