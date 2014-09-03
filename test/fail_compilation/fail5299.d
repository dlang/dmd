/*
TEST_OUTPUT:
---
fail_compilation/fail5299.d(12): Error: use of base class protection is no longer supported
---
*/

class A
{
}

class B : private A
{
}
