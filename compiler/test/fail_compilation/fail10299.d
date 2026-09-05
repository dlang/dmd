/*
TEST_OUTPUT:
---
fail_compilation/fail10299.d(11): Error: cannot take address of template instance `foo!string`
---
*/

template foo(T)
{
}
auto fp = &foo!string;    // ICE
