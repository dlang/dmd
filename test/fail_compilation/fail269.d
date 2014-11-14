/*
TEST_OUTPUT:
---
fail_compilation/fail269.d(13): Error: circular initialization of a
fail_compilation/fail269.d(12):        while evaluating b.init
fail_compilation/fail269.d(20): Error: circular initialization of bug7209
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
enum int bug7209 = bug7209;
