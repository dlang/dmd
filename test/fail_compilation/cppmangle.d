/*
TEST_OUTPUT:
---
fail_compilation/cppmangle.d(11): Error: expected valid identifer for C++ namespace but got ``
fail_compilation/cppmangle.d(15): Error: expected valid identifer for C++ namespace but got `0num`
fail_compilation/cppmangle.d(19): Error: expected string expression for namespace name, got `1 + 1`
fail_compilation/cppmangle.d(23): Error: expected valid identifer for C++ namespace but got `invalid@namespace`
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
