/*
TEST_OUTPUT:
---
fail_compilation/cppmangle.d(19): Error: expected valid identifier for C++ namespace but got ``
extern(C++, "")
            ^
fail_compilation/cppmangle.d(23): Error: expected valid identifier for C++ namespace but got `0num`
extern(C++, "0num")
            ^
fail_compilation/cppmangle.d(27): Error: compile time string constant (or sequence) expected, not `2`
extern(C++, 1+1)
            ^
fail_compilation/cppmangle.d(31): Error: expected valid identifier for C++ namespace but got `invalid@namespace`
extern(C++, "invalid@namespace")
            ^
---
*/

extern(C++, "")
{
}

extern(C++, "0num")
{
}

extern(C++, 1+1)
{
}

extern(C++, "invalid@namespace")
{
}
