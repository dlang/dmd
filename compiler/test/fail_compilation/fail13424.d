/*
TEST_OUTPUT:
---
fail_compilation/fail13424.d(18): Error: delegate `fail13424.S.__lambda_L18_C35` cannot be struct members
    void delegate(dchar) onChar = (dchar) {};
                                  ^
fail_compilation/fail13424.d(23): Error: delegate `fail13424.U.__lambda_L23_C35` cannot be union members
    void delegate(dchar) onChar = (dchar) {};
                                  ^
fail_compilation/fail13424.d(28): Error: delegate `fail13424.C.__lambda_L28_C35` cannot be class members
    void delegate(dchar) onChar = (dchar) {};
                                  ^
---
*/

struct S
{
    void delegate(dchar) onChar = (dchar) {};
}

union U
{
    void delegate(dchar) onChar = (dchar) {};
}

class C
{
    void delegate(dchar) onChar = (dchar) {};
}
