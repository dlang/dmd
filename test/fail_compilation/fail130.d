/*
TEST_OUTPUT:
---
fail_compilation/fail130.d(12): Error: functions cannot return a tuple
---
*/

template Tuple(T...) { alias T Tuple; }

alias Tuple!(int,int) TType;

TType foo()
{
    return TType;
}
