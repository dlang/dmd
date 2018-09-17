/*
TEST_OUTPUT:
---
fail_compilation/cppmangle.d(10): Error: invalid zero length C++ namespace
fail_compilation/cppmangle.d(14): Error: C++ namespace `0num` is invalid
fail_compilation/cppmangle.d(18): Error: string expected following `,` for C++ namespace
---
*/

extern(C++, "")
{
}

extern(C++, "0num")
{
}

extern(C++, "std", )
{
}



