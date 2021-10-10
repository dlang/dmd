/*
REQUIRED_ARGS: -w -o-

TEST_OUTPUT:
---
fail_compilation/noreturn2.d(18): Error: `return` expression expected
---

https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1034.md
*/

alias noreturn = typeof(*null);

void doStuff();

noreturn returnVoid()
{
    return doStuff();
}
