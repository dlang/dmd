/*
TEST_OUTPUT:
---
fail_compilation/fail141.d(11): Error: escaping reference to local variable string
---
*/

char* bar()
{
    char[4] string = "abcd";
    return string.ptr;
}
