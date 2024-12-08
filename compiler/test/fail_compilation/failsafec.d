/*
TEST_OUTPUT:
---
fail_compilation/failsafec.d(15): Error: `@safe` function `failsafec.callingsystem` cannot call `@system` delegate `sysdelegate`
    sysdelegate();
               ^
---
*/

void delegate() @system sysdelegate;

@safe
void callingsystem()
{
    sysdelegate();
}
