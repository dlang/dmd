/*
TEST_OUTPUT:
---
fail_compilation/failsafeb.d(15): Error: `@safe` function `failsafeb.callingsystem` cannot call `@system` function pointer `sysfuncptr`
    sysfuncptr();
              ^
---
*/

void function() @system sysfuncptr;

@safe
void callingsystem()
{
    sysfuncptr();
}
