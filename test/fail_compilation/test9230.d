/*
TEST_OUTPUT:
---
fail_compilation/test9230.d(9): Error: cannot implicitly convert expression (s) of type const(char[]) to string
---
*/

string foo(in char[] s) pure {
    return s; //
}
