/*
TEST_OUTPUT:
---
fail_compilation/fail207.d(13): Error: found end of file instead of initializer
fail_compilation/fail207.d(13): Error: semicolon needed to end declaration of `x`, instead of `End of File`
fail_compilation/fail207.d(12):        `x` declared here
int x = {
    ^
---
*/

int x = {
