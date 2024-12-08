/*
TEST_OUTPUT:
---
fail_compilation/failsafea.d(18): Error: `@safe` function `failsafea.callingsystem` cannot call `@system` function `failsafea.systemfunc`
    systemfunc();
              ^
fail_compilation/failsafea.d(13):        `failsafea.systemfunc` is declared here
void systemfunc() @system {}
     ^
---
*/

void systemfunc() @system {}

@safe
void callingsystem()
{
    systemfunc();
}
