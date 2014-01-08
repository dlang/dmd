/*
TEST_OUTPUT:
---
fail_compilation/fail269.d(11): Error: circular initialization of b
---
*/

version(D_Version2)
{
    enum int a = .b;
    enum int b = a;
}
else
{
    const int a = .b;
    const int b = .a;
}
