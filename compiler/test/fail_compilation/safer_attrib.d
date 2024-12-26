/*
TEST_OUTPUT:
---
fail_compilation/safer_attrib.d(10): Error: `void` initializers for pointers not allowed in safe functions
---
*/

void test1() @saferSystem
{
    int* p = void;
}

void foo3() { }

void test2()
{
    foo3(); // should not be an error
}
