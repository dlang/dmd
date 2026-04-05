/*
REQUIRED_ARGS:
TEST_OUTPUT:
---
fail_compilation/issue21622.d(14): Error: `issue21622.foo!0` matches multiple overloads
---
*/

void foo(int i)() {}
void foo(int i)() {}

void main()
{
    foo!0;
}
