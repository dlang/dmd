/*
TEST_OUTPUT:
---
fail_compilation/fail13424.d(10): Error: delegate fail13424.S.__lambda2 cannot be class members
---
*/

struct S
{
    void delegate(dchar) onChar = (dchar) {};
}
