/*
TEST_OUTPUT:
---
fail_compilation/safer_attrib2.d(15): Error: `@safe` function `safer_attrib2.saf` cannot call `@saferSystem` function `safer_attrib2.safSys`
fail_compilation/safer_attrib2.d(9):        `safer_attrib2.safSys` is declared here
---
*/

void safSys() @saferSystem
{
}

void saf() @safe
{
    safSys();
}

void sys() @system
{
    safSys(); // fine
}
