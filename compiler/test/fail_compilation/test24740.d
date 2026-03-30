/*
REQUIRED_ARGS:
TEST_OUTPUT:
---
fail_compilation/test24740.d(12): Error: cannot have parameter of type `void`
fail_compilation/test24740.d(15): Error: template instance `test24740.Bug!void` error instantiating
---
*/

template Bug(T)
{
    void BUG(T t){}
}

alias b = Bug!void;