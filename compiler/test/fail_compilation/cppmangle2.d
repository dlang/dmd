/*
TEST_OUTPUT:
---
fail_compilation/cppmangle2.d(11): Error: namespace `cppmangle2.ns` conflicts with variable `cppmangle2.ns` at fail_compilation/cppmangle2.d(10)
extern(C++, ns)
^
---
*/

enum ns = "ns";
extern(C++, ns)
{
}
