/*
TEST_OUTPUT:
---
fail_compilation/fail176.d(13): Error: cannot modify immutable expression b[1]
---
*/

void foo()
{
    auto a = "abc";
    immutable char[3] b = "abc";
    //const char[3] b = "abc";
    b[1] = 'd';
}
