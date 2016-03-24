// REQUIRED_ARGS: -transition=checkimports -de
/*
TEST_OUTPUT:
---
---
*/

template anySatisfy(T...)
{
    alias anySatisfy = T[$ - 1];
}

alias T = anySatisfy!(int);
