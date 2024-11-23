/*
TEST_OUTPUT:
---
fail_compilation/binexperr.d(16): Error: expression expected, not `)`
    if (A1*) {}
           ^
fail_compilation/binexperr.d(16): Error: missing closing `)` after `if (A1 * (__error)`
    if (A1*) {}
             ^
---
*/

void main()
{
    struct A1 {}
    if (A1*) {}
    return;
}
