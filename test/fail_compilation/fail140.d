/*
TEST_OUTPUT:
---
fail_compilation/fail140.d(11): Error: escaping reference to variable string
---
*/

char[] foo()
{
    char[4] string = "abcd";
    return string;
}
