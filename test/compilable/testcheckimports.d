// REQUIRED_ARGS: -transition=checkimports -de
/*
TEST_OUTPUT:
---
---
*/

// https://issues.dlang.org/show_bug.cgi?id=15825

template anySatisfy15825(T...)
{
    alias anySatisfy15825 = T[$ - 1];
}

alias T15825 = anySatisfy15825!(int);
